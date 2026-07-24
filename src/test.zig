//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const io = tst.io;
const math = std.math;
const EnvMap = std.process.Environ.Map;
const b = @import("builtin");

const config = @import("config").Config;
const report = @import("reports");
const typst = @import("typst");
const utils = @import("utils");
const zigmark = @import("zigmark");
const praxis_join = @import("praxis_join");
const controls = @import("controls");

const audit = @import("audit.zig");
const diagrams = @import("diagrams.zig");

// TODO
// - [ ] The reports should generate correctly

const TestConfig =
    \\base_url = "http://localhost:1111"
    \\[extra.policypress]
    \\redact_web = true
    \\policy_dir = "src/test"
    \\policy_root = "policies/_index.md"
    \\organization = "Star City Security Consulting"
    \\logo = "logo.png"
    \\pdf_color = "#0e90f3"
;

/// Builds a map of the current process environment for tests. Replaces the
/// removed `std.process.getEnvMap`.
fn testEnvMap(alloc: Allocator) !EnvMap {
    return std.process.Environ.createMap(tst.environ, alloc);
}

/// Absolute path of a testing TmpDir. `std.Io.Dir` no longer has `realpathAlloc`,
/// so reconstruct the path from the cwd and the tmp dir's cache-relative location.
fn tmpAbsPath(alloc: Allocator, tmp: *tst.TmpDir) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd_len = try std.process.currentPath(io, &buf);
    return std.fs.path.join(alloc, &.{ buf[0..cwd_len], ".zig-cache", "tmp", &tmp.sub_path });
}

/// Write `bytes` to `dir/name`, truncating any existing file. Small helper for
/// staging scratch fixtures (policies, fake PDFs) in the audit-bundle tests.
fn writeFileAt(alloc: Allocator, dir: []const u8, name: []const u8, bytes: []const u8) !void {
    const p = try std.fs.path.join(alloc, &.{ dir, name });
    defer alloc.free(p);
    const f = try std.Io.Dir.cwd().createFile(io, p, .{ .truncate = true });
    defer f.close(io);
    try f.writeStreamingAll(io, bytes);
}

test {
    _ = utils;
    _ = zigmark;
    _ = typst;
    _ = report;
    tst.refAllDecls(@This());
}

test "config loading and validation" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    // TestConfig sets redact_web = true but no `redact` key: redact_web is
    // web-only (#115) and does not by itself redact PDFs, and the config
    // `redact` key (#159) defaults off. So the two are independent and PDF
    // redaction is off here.
    try tst.expect(!conf.redact);
    try tst.expect(conf.redact_web);
    alloc.free(conf.content_dir);
    conf.content_dir = try std.fs.path.join(alloc, &.{
        conf.root,
        "src",
        "test",
    });
    alloc.free(conf.policy_dir);
    conf.policy_dir = try alloc.dupe(u8, conf.content_dir);

    try conf.validatePolicyFiles(io, alloc);
}

test "config: [extra.policypress] redact drives PDF redaction, independent of redact_web (#159)" {
    const alloc = tst.allocator;

    // Absent → off, preserving prior behavior (TestConfig has redact_web = true
    // but no `redact` key).
    {
        var conf = try config.load(io, alloc, TestConfig);
        defer conf.deinit(alloc);
        try tst.expect(!conf.redact);
        try tst.expect(conf.redact_web);
    }

    // `redact = true` turns PDF redaction on from config alone — the knob a
    // config-only consumer (e.g. via the Action) uses to keep links in step.
    {
        var conf = try config.load(io, alloc, TestConfig ++ "\nredact = true\n");
        defer conf.deinit(alloc);
        try tst.expect(conf.redact);
        try tst.expect(conf.redact_web);
    }

    // Independent of redact_web: web masking off, PDF redaction on.
    {
        const cfg =
            \\base_url = "http://localhost:1111"
            \\[extra.policypress]
            \\redact_web = false
            \\redact = true
            \\policy_dir = "src/test"
            \\organization = "Star City Security Consulting"
            \\logo = "logo.png"
            \\pdf_color = "#0e90f3"
        ;
        var conf = try config.load(io, alloc, cfg);
        defer conf.deinit(alloc);
        try tst.expect(conf.redact);
        try tst.expect(!conf.redact_web);
    }
}

test "config: control_footnotes defaults off and parses from [extra.policypress] (#173)" {
    const alloc = tst.allocator;
    // Absent → off, preserving the shortcode-only status quo.
    {
        var conf = try config.load(io, alloc, TestConfig);
        defer conf.deinit(alloc);
        try tst.expect(!conf.control_footnotes);
    }
    // Explicit true accepts native [^CONTROL-ID] footnote refs as first-class.
    {
        var conf = try config.load(io, alloc, TestConfig ++ "\ncontrol_footnotes = true\n");
        defer conf.deinit(alloc);
        try tst.expect(conf.control_footnotes);
    }
}

test "preflight: redact_web vs PDF redaction divergence is advisory (#159)" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig); // redact_web = true, redact = false
    defer conf.deinit(alloc);

    // Web masked but PDFs full → divergence (#115 permits it, flagged advisory).
    try tst.expectEqual(config.IssueKind.advisory, conf.reviewRedactionConsistency());

    // Aligned (both on) → clean.
    conf.redact = true;
    try tst.expectEqual(config.IssueKind.none, conf.reviewRedactionConsistency());

    // Both off → clean.
    conf.redact_web = false;
    conf.redact = false;
    try tst.expectEqual(config.IssueKind.none, conf.reviewRedactionConsistency());

    // PDFs redacted but web full → also a divergence.
    conf.redact = true;
    try tst.expectEqual(config.IssueKind.advisory, conf.reviewRedactionConsistency());
}

test "link↔file: PDF link matches on-disk filename across redact_web × redact (#159)" {
    const alloc = tst.allocator;
    const f = try std.Io.Dir.cwd().openFile(io, "src/test/test_policy.md", .{});
    defer f.close(io);
    const raw = try utils.readAllAlloc(io, f, alloc, std.math.maxInt(usize));
    defer alloc.free(raw);

    var contents = Array(u8).empty; // get_metadata reads it read-only, so reuse
    defer contents.deinit(alloc);
    try contents.appendSlice(alloc, raw);

    // The policy template keys the linked PDF filename off the effective PDF
    // redaction state (`redact`), NOT `redact_web`; the on-disk name follows the
    // same `redact` through get_metadata + FrontMatter.filename(). Assert the two
    // agree for every (redact_web, redact) so a PDF link never 404s — and, by
    // holding across both redact_web values, that redact_web is irrelevant to the
    // filename (the #159 fix; before it the link followed redact_web).
    inline for ([_]bool{ false, true }) |redact_web| {
        _ = redact_web;
        inline for ([_]bool{ false, true }) |redact| {
            var fm = try utils.get_metadata(alloc, &contents, .{ .redact = redact, .is_draft = false });
            defer fm.deinit(alloc);
            const on_disk = try fm.filename(alloc);
            defer alloc.free(on_disk);

            // Mirror templates/policies/page.html: slug(title) ~ infix ~ version.
            // slug("Test Policy") == "Test_Policy"; the newest revision is v1.1.
            const link = if (redact)
                try std.fmt.allocPrint(alloc, "Test_Policy__Redacted__-_v{s}.pdf", .{fm.most_recent_version})
            else
                try std.fmt.allocPrint(alloc, "Test_Policy_-_v{s}.pdf", .{fm.most_recent_version});
            defer alloc.free(link);

            try tst.expectEqualStrings(link, on_disk);
        }
    }
}

test "review preflight flags overdue policies" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    // Pin the build date so the last-reviewed age comparison is deterministic;
    // the default threshold is 365 days.
    conf.date = .{ .year = 2026, .month = 1, .day = 1 };
    try tst.expectEqual(@as(u32, 365), conf.review_overdue_days);
    // overdue_policy.md: last_reviewed 2000-01-01 -> critical.
    try tst.expectEqual(
        config.IssueKind.critical,
        conf.reviewPolicyFile(io, alloc, "src/test/overdue_policy.md"),
    );
    // fresh_policy.md: last_reviewed 2025-12-15 (17 days back) -> clean.
    try tst.expectEqual(
        config.IssueKind.none,
        conf.reviewPolicyFile(io, alloc, "src/test/fresh_policy.md"),
    );
}

test "ua-1 preflight flags heading-level skips only when pdf_standard is set" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    // Pin the date so heading_skip.md's recent review is never the reason.
    conf.date = .{ .year = 2026, .month = 1, .day = 1 };

    // Off by default: a heading skip is fine for a plain (non-tagged) PDF.
    try tst.expectEqual(@as(?[]const u8, null), conf.pdf_standard);
    try tst.expectEqual(
        config.IssueKind.none,
        conf.reviewPolicyFile(io, alloc, "src/test/heading_skip.md"),
    );

    // Opt-in to ua-1: the level skip becomes audit-critical.
    conf.pdf_standard = "ua-1";
    try tst.expectEqual(
        config.IssueKind.critical,
        conf.reviewPolicyFile(io, alloc, "src/test/heading_skip.md"),
    );
}

test "policy processing" {
    const test_policy_file = try std.Io.Dir.cwd().openFile(io, "src/test/test_policy.md", .{});
    defer test_policy_file.close(io);
    const test_policy = try utils.readAllAlloc(io, test_policy_file, tst.allocator, std.math.maxInt(usize));
    defer tst.allocator.free(test_policy);

    var frontmatter = try zigmark.Frontmatter.initFromMarkdown(tst.allocator, test_policy);
    defer frontmatter.deinit();
    try tst.expectEqualStrings("Test Policy", frontmatter.get("title").?.string);
    try tst.expectEqualStrings("A policy for testing purposes", frontmatter.get("description").?.string);
    try tst.expectEqualStrings("2024-11-13", frontmatter.get("date").?.string);
    try tst.expectEqual(.integer, std.meta.activeTag(frontmatter.get("weight").?));
    try tst.expectEqual(.object, std.meta.activeTag(frontmatter.get("taxonomies").?));
    try tst.expectEqual(.array, std.meta.activeTag(frontmatter.get("taxonomies.SCF").?));
    try tst.expectEqual(.array, std.meta.activeTag(frontmatter.get("taxonomies.TSC2017").?));
    try tst.expectEqual(.object, std.meta.activeTag(frontmatter.get("extra").?));
    try tst.expectEqual(.string, std.meta.activeTag(frontmatter.get("extra.owner").?));
    try tst.expectEqual(.array, std.meta.activeTag(frontmatter.get("extra.major_revisions").?));
    try tst.expectEqual(.object, std.meta.activeTag(frontmatter.get("extra.major_revisions").?.array.items[0]));
    const rev = frontmatter.get("extra.major_revisions").?.array.items[0].object;
    try tst.expect(rev.contains("date"));
    try tst.expect(rev.contains("description"));
    try tst.expect(rev.contains("revised_by"));
    try tst.expect(rev.contains("approved_by"));
    try tst.expect(rev.contains("version"));

    var t1 = Array(u8).empty;
    defer t1.deinit(tst.allocator);
    try t1.appendSlice(tst.allocator, test_policy);
    var f1 = try utils.get_metadata(tst.allocator, &t1, .{
        .redact = true,
        .is_draft = false,
    });
    defer f1.deinit(tst.allocator);
    try tst.expectEqualStrings("Test Policy (Redacted)", f1.title);
    try tst.expectEqualStrings("1.1", f1.most_recent_version);
    try tst.expectEqualStrings("2025-02-24", f1.last_reviewed);
    const out_file_name = try f1.filename(tst.allocator);
    defer tst.allocator.free(out_file_name);
    // filename() applies the canonical sanitiser, so "(Redacted)" becomes
    // "__Redacted__" — the actual name on disk, matching the site's links.
    try tst.expectEqualStrings("Test_Policy__Redacted__-_v1.1.pdf", out_file_name);

    try utils.replace_zola_at(tst.allocator, &t1, "https://test.lol");
    try utils.replace_org(tst.allocator, &t1, "loltest");
    try utils.replace_mermaid(tst.allocator, &t1);
    try utils.redact(tst.allocator, &t1, true);

    try tst.expect(std.mem.indexOf(u8, t1.items, "~~~mermaid") != null);
    // Redacted spans are masked with solid █ bars, not underscore placeholders.
    try tst.expect(std.mem.indexOf(u8, t1.items, "██████████") != null);
    try tst.expectEqual(3, std.mem.count(u8, t1.items, "https://test.lol/"));
    try tst.expectEqual(0, std.mem.count(u8, t1.items, "{% end %}"));
}
test "pdf rendering" {
    var env = try testEnvMap(tst.allocator);
    defer env.deinit();
    if (!utils.executableInPath(io, &env, "typst")) return error.SkipZigTest;

    var tmp = tst.tmpDir(.{});

    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    // Free and replace root
    alloc.free(conf.content_dir);
    conf.content_dir = try std.fs.path.join(alloc, &.{
        conf.root,
        "src",
        "test",
    });
    alloc.free(conf.policy_dir);
    conf.policy_dir = try alloc.dupe(u8, conf.content_dir);
    conf.build_dir = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(conf.build_dir);

    // test_policy.md contains a mermaid diagram: unlike the pandoc pipeline
    // (which needed Chrome for mermaid-filter), pozeiden renders it in-process
    // so the full pipeline works even inside the Nix sandbox.
    typst.compile(io, &env, tst.allocator, conf, "src/test/test_policy.md", null, null) catch |e| {
        std.debug.print("Test Policy Typst Call Failed! \nConfig:{f}\n", .{conf});
        return e;
    };

    // Verify the PDF was actually written to the output directory.
    // Re-open with iterate permission; the tmpDir handle lacks it by default.
    var out_dir = try std.Io.Dir.openDirAbsolute(io, conf.build_dir, .{ .iterate = true });
    defer out_dir.close(io);
    var pdf_found = false;
    var dir_iter = out_dir.iterate();
    while (try dir_iter.next(io)) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".pdf")) {
            pdf_found = true;
            break;
        }
    }
    try tst.expect(pdf_found);

    tmp.cleanup();
}

test "typst source: mermaid renders as inline svg via pozeiden" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    var rendered = try typst.render(io, alloc, conf, "src/test/test_policy.md");
    defer rendered.deinit(alloc);

    // The mermaid fenced block must become an embedded SVG image, not a
    // leftover code block (which would mean pozeiden silently failed).
    try tst.expect(std.mem.indexOf(u8, rendered.source, "bytes(\"<svg") != null);
    try tst.expect(std.mem.indexOf(u8, rendered.source, "```mermaid") == null);
}

test "typst source: opt-in math emits mitex import and calls" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    var rendered = try typst.render(io, alloc, conf, "src/test/test_policy_math.md");
    defer rendered.deinit(alloc);

    // The consumer preamble must import mitex (zigmark emits `#mi`/`#mitex`
    // calls but never the import).
    try tst.expect(std.mem.indexOf(u8, rendered.source, "#import \"@preview/mitex:0.2.7\": mi, mitex") != null);
    // zigmark v0.10.0 carries per-equation alt text (the TeX source), which
    // typst's PDF/UA-1 mode requires — no document-wide fallback needed.
    try tst.expect(std.mem.indexOf(u8, rendered.source, "#set math.equation(alt:") == null);
    // Inline `$…$` → `#mi("…", alt: "…")`, display `$$…$$` → `#mitex("…", alt: "…")`.
    try tst.expect(std.mem.indexOf(u8, rendered.source, "#mi(\"R > 15\", alt: \"R > 15\")") != null);
    try tst.expect(std.mem.indexOf(u8, rendered.source, "#mitex(") != null);
    // #136: a Markdown image's alt text becomes the Typst `image(alt:)` arg.
    try tst.expect(std.mem.indexOf(u8, rendered.source, "alt: \"Risk scoring matrix\"") != null);
    // Root-absolute image path is rewritten to its static/ location for --root.
    try tst.expect(std.mem.indexOf(u8, rendered.source, "image(\"/static/diagram.png\"") != null);
}

test "typst source: math stays off without extra.math opt-in" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    // test_policy_math_off.md CONTAINS `$…$` / `$$…$$` math syntax but does NOT
    // set extra.math. With the gate off, zigmark parses `$` as ordinary text and
    // escapes it to `\$`; nothing becomes a mitex equation. This guards the
    // opt-in gate against a regression to always-on (a fixture with no math
    // could not catch that — there'd be nothing to mis-parse).
    var rendered = try typst.render(io, alloc, conf, "src/test/test_policy_math_off.md");
    defer rendered.deinit(alloc);

    // The `$` in `$x^2$` stays escaped as literal text — not opened as math.
    try tst.expect(std.mem.indexOf(u8, rendered.source, "\\$x^2\\$") != null);
    // No equation was emitted: neither the inline `#mi(` nor the display
    // `#mitex(` renderer calls, and thus no mitex import either.
    try tst.expect(std.mem.indexOf(u8, rendered.source, "#mi(") == null);
    try tst.expect(std.mem.indexOf(u8, rendered.source, "#mitex(") == null);
    try tst.expect(std.mem.indexOf(u8, rendered.source, "@preview/mitex") == null);
}

test "typst source: redaction produces solid bars" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    conf.redact = true;

    var rendered = try typst.render(io, alloc, conf, "src/test/test_policy.md");
    defer rendered.deinit(alloc);

    // Redacted spans must render as solid █ bars, not underscores (which
    // CommonMark would turn into thematic breaks).
    try tst.expect(std.mem.indexOf(u8, rendered.source, "█") != null);
    // Golden no-leak: the redact block's content must NOT survive anywhere in
    // the Typst source that becomes the redacted PDF.
    try tst.expect(std.mem.indexOf(u8, rendered.source, "sensitive information that should not be disclosed") == null);
    // No unconsumed redaction tag may remain either.
    try tst.expect(std.mem.indexOf(u8, rendered.source, "{% redact") == null);
    // Sanitised filename carries the __Redacted__ pattern that the Zola
    // templates hardcode in PDF links (issue #97).
    try tst.expectEqualStrings("Test_Policy__Redacted__-_v1.1.pdf", rendered.pdf_name);
}

test "report generation" {

    // var tmp = tst.tmpDir(.{});
    // const builddir = try tmpAbsPath(tst.allocator, &tmp);
    // defer tst.allocator.free(builddir);

    // var f = try report.init(io, tst.allocator, "data/scf.json");
    // defer f.deinit();

    // const rep = try f.report(io, "content/policies");
    // var j = try std.json.parseFromSlice(std.json.Value, tst.allocator, rep, .{});
    // defer j.deinit();
    // try tst.expect(j.value.object.count() >= 1468); // number of controls in the SCF 2026.1.1 catalog
    // try tst.expect(j.value.object.get("HRS-05").?.bool);
    // try tst.expect(j.value.object.get("HRS-05.1").?.bool);
    // try tst.expect(j.value.object.get("HRS-05.2").?.bool);
    // try tst.expect(j.value.object.get("HRS-05.3").?.bool);
    // try tst.expect(j.value.object.get("HRS-05.4").?.bool);
    // try tst.expect(j.value.object.get("HRS-05.5").?.bool);
}

// ============================================================
// Stamp-file caching (incremental builds)
// ============================================================

test "stamp: no stamp → always rebuild" {
    const alloc = tst.allocator;
    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    try tmp.dir.writeFile(io, .{ .sub_path = "policy.md", .data = "content" });
    const src_path = try std.fs.path.join(alloc, &.{ tmp_path, "policy.md" });
    defer alloc.free(src_path);

    try tst.expect(!utils.stampIsNewer(io, src_path, tmp_path, alloc));
}

test "stamp: writeStamp → stampIsNewer returns true" {
    const alloc = tst.allocator;
    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    try tmp.dir.writeFile(io, .{ .sub_path = "policy.md", .data = "content" });
    const src_path = try std.fs.path.join(alloc, &.{ tmp_path, "policy.md" });
    defer alloc.free(src_path);

    utils.writeStamp(io, alloc, tmp_path, src_path);

    // Set stamp mtime to 2 s in the future so it is definitely newer. The
    // stamp filename is keyed by the full path (separators flattened), not the
    // bare stem, so two same-named policies in different dirs never collide.
    const stamp_name = try utils.stampName(alloc, src_path);
    defer alloc.free(stamp_name);
    const stamp_path = try std.fs.path.join(alloc, &.{ tmp_path, stamp_name });
    defer alloc.free(stamp_path);
    const stamp_file = try std.Io.Dir.cwd().openFile(io, stamp_path, .{ .mode = .read_write });
    defer stamp_file.close(io);
    const now = std.Io.Timestamp.now(io, .real);
    const future = std.Io.Timestamp.fromNanoseconds(now.toNanoseconds() + 2_000_000_000);
    try stamp_file.setTimestamps(io, .{
        .access_timestamp = .{ .new = now },
        .modify_timestamp = .{ .new = future },
    });

    try tst.expect(utils.stampIsNewer(io, src_path, tmp_path, alloc));
}

test "stamp: writeStamp creates a stamp file keyed by full path" {
    const alloc = tst.allocator;
    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    try tmp.dir.writeFile(io, .{ .sub_path = "access-control.md", .data = "body" });
    const src_path = try std.fs.path.join(alloc, &.{ tmp_path, "access-control.md" });
    defer alloc.free(src_path);

    try tst.expect(!utils.stampIsNewer(io, src_path, tmp_path, alloc));
    utils.writeStamp(io, alloc, tmp_path, src_path);

    const stamp_name = try utils.stampName(alloc, src_path);
    defer alloc.free(stamp_name);
    const stamp_path = try std.fs.path.join(alloc, &.{ tmp_path, stamp_name });
    defer alloc.free(stamp_path);
    try std.Io.Dir.accessAbsolute(io, stamp_path, .{});
}

test "stamp: same filename in different dirs gets distinct stamps" {
    // Regression: keying stamps by basename made two policies with the same
    // file name (access/policy.md vs data/policy.md) share one stamp, so the
    // second was skipped as "up to date" and its PDF never produced.
    const alloc = tst.allocator;
    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    try tmp.dir.createDirPath(io, "access");
    try tmp.dir.createDirPath(io, "data");
    try tmp.dir.writeFile(io, .{ .sub_path = "access/policy.md", .data = "a" });
    try tmp.dir.writeFile(io, .{ .sub_path = "data/policy.md", .data = "b" });

    const a_path = try std.fs.path.join(alloc, &.{ tmp_path, "access/policy.md" });
    defer alloc.free(a_path);
    const b_path = try std.fs.path.join(alloc, &.{ tmp_path, "data/policy.md" });
    defer alloc.free(b_path);

    const a_name = try utils.stampName(alloc, a_path);
    defer alloc.free(a_name);
    const b_name = try utils.stampName(alloc, b_path);
    defer alloc.free(b_name);
    // Distinct keys, and neither contains a path separator.
    try tst.expect(!std.mem.eql(u8, a_name, b_name));
    try tst.expect(std.mem.indexOfScalar(u8, a_name, '/') == null);

    // Stamping the first must not mark the second as up to date.
    utils.writeStamp(io, alloc, tmp_path, a_path);
    try tst.expect(!utils.stampIsNewer(io, b_path, tmp_path, alloc));
}

// ============================================================
// Issue #67: Full Pipeline Tests
// ============================================================

// --- Bad Config → Clear Error ---

test "bad config: missing extra section" {
    try tst.expectError(
        error.NoExtraInZolaConfig,
        config.load(io, tst.allocator, "base_url = \"http://localhost\""),
    );
}

test "bad config: missing logo" {
    const bad =
        \\base_url = "http://localhost"
        \\[extra.policypress]
        \\organization = "ACME"
        \\pdf_color = "#000"
        \\policy_dir = "."
    ;
    try tst.expectError(error.NoLogoInExtra, config.load(io, tst.allocator, bad));
}

test "bad config: missing organization" {
    const bad =
        \\base_url = "http://localhost"
        \\[extra.policypress]
        \\logo = "logo.png"
        \\pdf_color = "#000"
        \\policy_dir = "."
    ;
    try tst.expectError(error.NoOrganizationInExtra, config.load(io, tst.allocator, bad));
}

test "bad config: missing pdf_color" {
    const bad =
        \\base_url = "http://localhost"
        \\[extra.policypress]
        \\logo = "logo.png"
        \\organization = "ACME"
        \\policy_dir = "."
    ;
    try tst.expectError(error.NoPDFColorInExtra, config.load(io, tst.allocator, bad));
}

test "bad config: missing base_url" {
    const bad =
        \\[extra.policypress]
        \\logo = "logo.png"
        \\organization = "ACME"
        \\pdf_color = "#000"
        \\policy_dir = "."
    ;
    try tst.expectError(error.NoBaseUrlInZolaConfig, config.load(io, tst.allocator, bad));
}

// --- Missing Frontmatter → Helpful Error ---
// These exercise get_metadata (runtime pipeline path) and validateFrontMatter
// (pre-flight validation path) independently.

const full_revision =
    \\  - date: "2024-01-01"
    \\    description: "Initial"
    \\    revised_by: "Author"
    \\    approved_by: "Approver"
    \\    version: "1.0"
;

fn makePolicyMd(comptime frontmatter: []const u8) []const u8 {
    return "---\n" ++ frontmatter ++ "\n---\nBody.\n";
}

test "missing frontmatter: no title → NoTitleInFrontMatter" {
    const alloc = tst.allocator;
    const md = makePolicyMd(
        \\description: "Test"
        \\extra:
        \\  last_reviewed: "2024-01-01"
        \\  major_revisions:
        ++ "\n" ++ full_revision,
    );
    var arr = Array(u8).empty;
    defer arr.deinit(alloc);
    try arr.appendSlice(alloc, md);
    try tst.expectError(
        error.NoTitleInFrontMatter,
        utils.get_metadata(alloc, &arr, .{ .redact = false, .is_draft = false }),
    );
}

test "missing frontmatter: no last_reviewed → NoLastReviewInFrontMatter" {
    const alloc = tst.allocator;
    const md = makePolicyMd(
        \\title: "Test Policy"
        \\description: "Test"
        \\extra:
        \\  major_revisions:
        ++ "\n" ++ full_revision,
    );
    var arr = Array(u8).empty;
    defer arr.deinit(alloc);
    try arr.appendSlice(alloc, md);
    try tst.expectError(
        error.NoLastReviewInFrontMatter,
        utils.get_metadata(alloc, &arr, .{ .redact = false, .is_draft = false }),
    );
}

test "missing frontmatter: no revisions → NoRevisionsInFrontMatter" {
    const alloc = tst.allocator;
    const md = makePolicyMd(
        \\title: "Test Policy"
        \\description: "Test"
        \\extra:
        \\  last_reviewed: "2024-01-01"
        ,
    );
    var arr = Array(u8).empty;
    defer arr.deinit(alloc);
    try arr.appendSlice(alloc, md);
    try tst.expectError(
        error.NoRevisionsInFrontMatter,
        utils.get_metadata(alloc, &arr, .{ .redact = false, .is_draft = false }),
    );
}

test "frontmatter: trailing YAML comment after a scalar parses (zig-yaml 0.3.1)" {
    // Regression for the sc2in/zig-yaml fix bundled in zigmark v0.9.0: a
    // trailing `# comment` after a plain scalar in a block sequence entry
    // previously failed the whole document with ParseFailure. A policy author
    // annotating a revision date with a comment must not break the build.
    const alloc = tst.allocator;
    const md = makePolicyMd(
        \\title: "Test Policy"
        \\description: "Test"
        \\extra:
        \\  last_reviewed: "2024-01-01"  # last audit
        \\  major_revisions:
        \\  - date: "2024-01-01"  # when
        \\    description: "Initial"
        \\    revised_by: "Author"
        \\    approved_by: "Approver"
        \\    version: "1.0"
        ,
    );
    var arr = Array(u8).empty;
    defer arr.deinit(alloc);
    try arr.appendSlice(alloc, md);
    // Parses cleanly (no ParseFailure) and the commented values are intact.
    var fm = try utils.get_metadata(alloc, &arr, .{ .redact = false, .is_draft = false });
    defer fm.deinit(alloc);
    try tst.expectEqualStrings("2024-01-01", fm.last_reviewed);
    try tst.expectEqualStrings("1.0", fm.most_recent_version);
}

test "missing frontmatter: description → NoDescriptionInFrontMatter" {
    const alloc = tst.allocator;
    const md = makePolicyMd(
        \\title: "Test Policy"
        \\extra:
        \\  last_reviewed: "2024-01-01"
        \\  major_revisions:
        ++ "\n" ++ full_revision,
    );
    var fm = try zigmark.Frontmatter.initFromMarkdown(alloc, md);
    defer fm.deinit();
    // validateFrontMatter ignores its Config receiver
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    try tst.expectError(error.NoDescriptionInFrontMatter, conf.validateFrontMatter(fm));
}

test "missing frontmatter: revision missing date → NoDateForRevision" {
    const alloc = tst.allocator;
    const md = makePolicyMd(
        \\title: "Test Policy"
        \\description: "Test"
        \\extra:
        \\  last_reviewed: "2024-01-01"
        \\  major_revisions:
        \\  - description: "Initial"
        \\    approved_by: "Approver"
        \\    version: "1.0"
        ,
    );
    var fm = try zigmark.Frontmatter.initFromMarkdown(alloc, md);
    defer fm.deinit();
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    try tst.expectError(error.NoDateForRevision, conf.validateFrontMatter(fm));
}

test "missing frontmatter: revision missing approved_by → NoApprovalForRevision" {
    const alloc = tst.allocator;
    const md = makePolicyMd(
        \\title: "Test Policy"
        \\description: "Test"
        \\extra:
        \\  last_reviewed: "2024-01-01"
        \\  major_revisions:
        \\  - date: "2024-01-01"
        \\    description: "Initial"
        \\    version: "1.0"
        ,
    );
    var fm = try zigmark.Frontmatter.initFromMarkdown(alloc, md);
    defer fm.deinit();
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    try tst.expectError(error.NoApprovalForRevision, conf.validateFrontMatter(fm));
}

test "empty frontmatter: blank approved_by → EmptyApprovalForRevision" {
    const alloc = tst.allocator;
    // Present but empty: an audit PDF must not claim approval by nobody.
    const md = makePolicyMd(
        \\title: "Test Policy"
        \\description: "Test"
        \\extra:
        \\  last_reviewed: "2024-01-01"
        \\  major_revisions:
        \\  - date: "2024-01-01"
        \\    description: "Initial"
        \\    approved_by: "   "
        \\    version: "1.0"
        ,
    );
    var fm = try zigmark.Frontmatter.initFromMarkdown(alloc, md);
    defer fm.deinit();
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    try tst.expectError(error.EmptyApprovalForRevision, conf.validateFrontMatter(fm));
}

// --- Raw HTML divergence (#117): the site renders it, PDFs silently drop it ---

test "raw html: block-level HTML is detected" {
    const alloc = tst.allocator;
    const f = (try config.findRawHtml(alloc, "Before.\n\n<div class=\"tab-group\">\n<p>site-only</p>\n</div>\n\nAfter.\n")).?;
    defer f.deinit(alloc);
    try tst.expect(f.kind == .block);
    try tst.expect(std.mem.startsWith(u8, f.snippet, "<div"));
}

test "raw html: inline HTML is detected" {
    const alloc = tst.allocator;
    const f = (try config.findRawHtml(alloc, "Some <span class=\"x\">text</span> here.\n")).?;
    defer f.deinit(alloc);
    try tst.expect(f.kind == .in_line);
}

test "raw html: nested containers are walked (list > quote > inline)" {
    const alloc = tst.allocator;
    const f = (try config.findRawHtml(alloc, "- item\n\n  > quoted <br> break\n")).?;
    defer f.deinit(alloc);
    try tst.expect(f.kind == .in_line);
}

test "raw html: code fences, code spans, and autolinks do not trip" {
    const alloc = tst.allocator;
    try tst.expect((try config.findRawHtml(alloc, "```html\n<div>not raw</div>\n```\n")) == null);
    try tst.expect((try config.findRawHtml(alloc, "Use `<div>` for layout.\n")) == null);
    // Email/URI autolinks parse as .autolink, not inline HTML — the demo
    // content relies on this (example-security-policy.md uses <security-team@…>).
    try tst.expect((try config.findRawHtml(alloc, "Contact <security-team@organization.com>.\n")) == null);
    try tst.expect((try config.findRawHtml(alloc, "See <https://example.com> for details.\n")) == null);
}

test "review: raw HTML in body → critical; clean body → none" {
    const alloc = tst.allocator;
    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    const html_policy =
        \\---
        \\title: "Test Policy"
        \\description: "Test"
        \\extra:
        \\  last_reviewed: "2024-01-01"
        \\  major_revisions:
        \\  - date: "2024-01-01"
        \\    description: "Initial"
        \\    revised_by: "Author"
        \\    approved_by: "Approver"
        \\    version: "1.0"
        \\---
        \\Body text.
        \\
        \\<div class="note">raw</div>
        \\
    ;
    const clean_policy =
        \\---
        \\title: "Test Policy"
        \\description: "Test"
        \\extra:
        \\  last_reviewed: "2024-01-01"
        \\  major_revisions:
        \\  - date: "2024-01-01"
        \\    description: "Initial"
        \\    revised_by: "Author"
        \\    approved_by: "Approver"
        \\    version: "1.0"
        \\---
        \\Body text — pure Markdown, no raw HTML.
        \\
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "html_policy.md", .data = html_policy });
    try tmp.dir.writeFile(io, .{ .sub_path = "clean_policy.md", .data = clean_policy });

    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    // Pin the date near the fixtures' 2024-01-01 review so this test isolates
    // raw-HTML detection from the separate overdue-review check.
    conf.date = .{ .year = 2024, .month = 6, .day = 1 };

    const html_path = try std.fs.path.join(alloc, &.{ tmp_path, "html_policy.md" });
    defer alloc.free(html_path);
    const clean_path = try std.fs.path.join(alloc, &.{ tmp_path, "clean_policy.md" });
    defer alloc.free(clean_path);

    try tst.expectEqual(config.IssueKind.critical, conf.reviewPolicyFile(io, alloc, html_path));
    try tst.expectEqual(config.IssueKind.none, conf.reviewPolicyFile(io, alloc, clean_path));
}

test "review: advisory front matter + raw HTML body → critical (max wins)" {
    const alloc = tst.allocator;
    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // No top-level `description` (advisory) *and* raw HTML in the body: the
    // more severe classification must win.
    const advisory_html =
        \\---
        \\title: "Test Policy"
        \\extra:
        \\  last_reviewed: "2024-01-01"
        \\  major_revisions:
        \\  - date: "2024-01-01"
        \\    description: "Initial"
        \\    revised_by: "Author"
        \\    approved_by: "Approver"
        \\    version: "1.0"
        \\---
        \\Body text.
        \\
        \\<span>inline markup</span>
        \\
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "advisory_html.md", .data = advisory_html });

    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    // Pin near the fixture's 2024-01-01 review so the raw-HTML critical, not the
    // overdue-review critical, is what this "max wins over advisory" test asserts.
    conf.date = .{ .year = 2024, .month = 6, .day = 1 };

    const path = try std.fs.path.join(alloc, &.{ tmp_path, "advisory_html.md" });
    defer alloc.free(path);

    try tst.expectEqual(config.IssueKind.critical, conf.reviewPolicyFile(io, alloc, path));
}

// --- Draft Mode Adds Watermark ---

test "draft mode: typst source includes draft.png page background" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    conf.is_draft = true;
    var rendered = try typst.render(io, alloc, conf, "src/test/test_policy_render.md");
    defer rendered.deinit(alloc);

    // The repository root ships static/draft.png, so the watermark helper is
    // defined and applied as the page background (body pages + title page).
    try tst.expect(std.mem.indexOf(u8, rendered.source, "#let _pp_draft_bg") != null);
    try tst.expect(std.mem.indexOf(u8, rendered.source, "draft.png") != null);
    try tst.expectEqual(2, std.mem.count(u8, rendered.source, "background: _pp_draft_bg"));
}

test "redact mode: typst source includes a REDACTED title-page banner" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    conf.redact = true;
    var rendered = try typst.render(io, alloc, conf, "src/test/test_policy_render.md");
    defer rendered.deinit(alloc);

    try tst.expect(std.mem.indexOf(u8, rendered.source, "[REDACTED]") != null);
}

test "non-redact mode: typst source has no REDACTED banner" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    conf.redact = false;
    var rendered = try typst.render(io, alloc, conf, "src/test/test_policy_render.md");
    defer rendered.deinit(alloc);

    try tst.expect(std.mem.indexOf(u8, rendered.source, "[REDACTED]") == null);
}

test "classification: config default appears in the footer, and can be overridden" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    // Default preserves the historical "Confidential" footer.
    try tst.expectEqualStrings("Confidential", conf.classification);
    var r1 = try typst.render(io, alloc, conf, "src/test/test_policy_render.md");
    defer r1.deinit(alloc);
    try tst.expect(std.mem.indexOf(u8, r1.source, "Confidential") != null);

    // A site-wide override flows into the footer.
    conf.classification = "Internal Use Only";
    var r2 = try typst.render(io, alloc, conf, "src/test/test_policy_render.md");
    defer r2.deinit(alloc);
    try tst.expect(std.mem.indexOf(u8, r2.source, "Internal Use Only") != null);
}

test "non-draft mode: typst source excludes draft background" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    conf.is_draft = false;
    var rendered = try typst.render(io, alloc, conf, "src/test/test_policy_render.md");
    defer rendered.deinit(alloc);

    try tst.expect(std.mem.indexOf(u8, rendered.source, "_pp_draft_bg") == null);
    try tst.expect(std.mem.indexOf(u8, rendered.source, "draft.png") == null);
}

// --- Redact Mode Removes Sensitive Content ---
// The unit tests below cover redact() directly. The pipeline wiring test
// ("redact mode: title suffix and content scrubbed") confirms get_metadata and
// redact() integrate correctly end-to-end.

test "redact: well-formed block is redacted" {
    const t =
        \\{% redact() %}
        \\This is sensitive information that should be redacted.
        \\{% end %}
    ;
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, t);
    try utils.redact(tst.allocator, &ts, true);
    // The span is masked with solid █ bars; no plaintext and no tags survive.
    try tst.expect(std.mem.indexOf(u8, ts.items, "sensitive") == null);
    try tst.expect(std.mem.indexOf(u8, ts.items, "{%") == null);
    try tst.expect(std.mem.indexOf(u8, ts.items, "█") != null);
    // No underscore placeholder leaks through (the old two-pass artefact).
    try tst.expect(std.mem.indexOfScalar(u8, ts.items, '_') == null);
}

test "redact: whitespace-trim tag variant is still redacted" {
    // Tera trim markers ({%- ... -%}) must not let a block slip past the
    // redactor unmasked.
    const t =
        \\{%- redact() -%}
        \\leaked secret value
        \\{%- end -%}
    ;
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, t);
    try utils.redact(tst.allocator, &ts, true);
    try tst.expect(std.mem.indexOf(u8, ts.items, "leaked secret") == null);
    try tst.expect(std.mem.indexOf(u8, ts.items, "█") != null);
}

test "redact: legitimate underscores in the body survive" {
    // Only the redacted span is masked; snake_case identifiers, _emphasis_,
    // and URLs elsewhere keep their underscores intact.
    const t =
        \\Set MAX_RETRY_COUNT and read the audit_log at /docs/my_page.
        \\Use _emphasis_ freely.
        \\{% redact() %}hide me{% end %}
    ;
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, t);
    try utils.redact(tst.allocator, &ts, true);
    try tst.expect(std.mem.indexOf(u8, ts.items, "MAX_RETRY_COUNT") != null);
    try tst.expect(std.mem.indexOf(u8, ts.items, "audit_log") != null);
    try tst.expect(std.mem.indexOf(u8, ts.items, "my_page") != null);
    try tst.expect(std.mem.indexOf(u8, ts.items, "_emphasis_") != null);
    try tst.expect(std.mem.indexOf(u8, ts.items, "hide me") == null);
    try tst.expect(std.mem.indexOf(u8, ts.items, "█") != null);
}

test "redact: well-formed block is unredacted when remove=false" {
    const t =
        \\{% redact() %}
        \\sensitive content
        \\{% end %}
    ;
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, t);
    try utils.redact(tst.allocator, &ts, false);
    try tst.expect(std.mem.indexOf(u8, ts.items, "sensitive content") != null);
}

test "redact: unclosed opening tag returns UnclosedRedaction" {
    // An opening {% redact() %} with no matching {% end %} must never pass
    // through silently — the build must fail with UnclosedRedaction.
    const t =
        \\{% redact() %}
        \\This sensitive content has no closing tag.
    ;
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, t);
    try tst.expectError(error.UnclosedRedaction, utils.redact(tst.allocator, &ts, true));
}

test "redact: dangling end tag returns UnclosedRedaction" {
    // A {% end %} with no matching {% redact() %} must also be caught.
    const t =
        \\Normal text with no opening tag.
        \\{% end %}
    ;
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, t);
    try tst.expectError(error.UnclosedRedaction, utils.redact(tst.allocator, &ts, true));
}

test "redact: multiple blocks are all redacted" {
    // Every block must be redacted; none may slip through if the iterator
    // resets correctly after each replacement.
    const t =
        \\{% redact() %}first secret{% end %} public {% redact() %}second secret{% end %}
    ;
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, t);
    try utils.redact(tst.allocator, &ts, true);
    try tst.expect(std.mem.indexOf(u8, ts.items, "secret") == null);
}

test "control refs: a valid reference is rewritten to a footnote reference" {
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, "Access is least-privilege {{ control(id=\"IAC-01\") }} enforced.");
    try utils.replace_control_refs(tst.allocator, &ts);
    try tst.expectEqualStrings("Access is least-privilege [^IAC-01] enforced.", ts.items);
}

test "control refs: multiple references are all rewritten" {
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    // Second ref uses the no-whitespace form to exercise \s* on both ends.
    try ts.appendSlice(tst.allocator, "See {{ control(id=\"IAC-01\") }} and {{control(id=\"CRY-01\")}}.");
    try utils.replace_control_refs(tst.allocator, &ts);
    try tst.expectEqualStrings("See [^IAC-01] and [^CRY-01].", ts.items);
}

test "control refs: a dotted sub-control id is accepted" {
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, "Ref {{ control(id=\"IAC-21.5\") }} here.");
    try utils.replace_control_refs(tst.allocator, &ts);
    try tst.expectEqualStrings("Ref [^IAC-21.5] here.", ts.items);
}

test "control refs: a malformed id is a hard error" {
    // Lowercase / single-digit id fails the [A-Z]{2,5}-[0-9]{2}… pattern, so the
    // leftover control( opener trips the strictness check (mirrors redact's
    // orphan-tag handling).
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, "Bad {{ control(id=\"iac-1\") }} ref.");
    try tst.expectError(error.MalformedControlRef, utils.replace_control_refs(tst.allocator, &ts));
}

test "control refs: the org shortcode is not a false positive" {
    // No control shortcode present — must be a no-op with no spurious error.
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);
    try ts.appendSlice(tst.allocator, "Welcome to {{ org() }}!");
    try utils.replace_control_refs(tst.allocator, &ts);
    try tst.expectEqualStrings("Welcome to {{ org() }}!", ts.items);
}

test "redact mode: title suffix and content scrubbed" {
    const alloc = tst.allocator;
    const test_policy_file = try std.Io.Dir.cwd().openFile(io, "src/test/test_policy.md", .{});
    defer test_policy_file.close(io);
    const raw = try utils.readAllAlloc(io, test_policy_file, alloc, std.math.maxInt(usize));
    defer alloc.free(raw);

    var contents = Array(u8).empty;
    defer contents.deinit(alloc);
    try contents.appendSlice(alloc, raw);

    try utils.replace_org(alloc, &contents, "TestOrg");
    try utils.replace_zola_at(alloc, &contents, "https://example.com");
    try utils.replace_mermaid(alloc, &contents);
    try utils.redact(alloc, &contents, true);

    var fm = try utils.get_metadata(alloc, &contents, .{ .redact = true, .is_draft = false });
    defer fm.deinit(alloc);

    // Title must carry the (Redacted) suffix.
    try tst.expect(std.mem.indexOf(u8, fm.title, "(Redacted)") != null);
    // No unprocessed shortcode tags should remain.
    try tst.expect(std.mem.indexOf(u8, contents.items, "{% end %}") == null);
    // Redacted blocks become solid █ bars, not visible text.
    try tst.expect(std.mem.indexOf(u8, contents.items, "██████████") != null);
}

// --- draft.png path resolution ---

test "draft mode: uses site-root static/draft.png when present" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);
    try tmp.dir.createDirPath(io, "static");
    try tmp.dir.writeFile(io, .{ .sub_path = "static/draft.png", .data = "" });

    alloc.free(conf.root);
    conf.root = try alloc.dupe(u8, tmp_path);
    conf.is_draft = true;

    const path = (try typst.resolveDraftPng(io, alloc, conf)) orelse return error.NoDraftPng;
    defer alloc.free(path);
    // Must point at the site-root copy, not the theme fallback.
    try tst.expect(std.mem.indexOf(u8, path, "static" ++ std.fs.path.sep_str ++ "draft.png") != null);
    try tst.expect(std.mem.indexOf(u8, path, "themes" ++ std.fs.path.sep_str ++ "policypress") == null);
}

test "draft mode: falls back to themes/policypress/static/draft.png when site-root copy absent" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);
    try tmp.dir.createDirPath(io, "themes/policypress/static");
    try tmp.dir.writeFile(io, .{ .sub_path = "themes/policypress/static/draft.png", .data = "" });

    alloc.free(conf.root);
    conf.root = try alloc.dupe(u8, tmp_path);
    conf.is_draft = true;

    const path = (try typst.resolveDraftPng(io, alloc, conf)) orelse return error.NoDraftPng;
    defer alloc.free(path);
    try tst.expect(std.mem.indexOf(u8, path, "themes" ++ std.fs.path.sep_str ++ "policypress" ++ std.fs.path.sep_str ++ "static" ++ std.fs.path.sep_str ++ "draft.png") != null);
}

test "draft mode: site-root static/draft.png wins over theme fallback when both exist" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);
    try tmp.dir.createDirPath(io, "static");
    try tmp.dir.writeFile(io, .{ .sub_path = "static/draft.png", .data = "" });
    try tmp.dir.createDirPath(io, "themes/policypress/static");
    try tmp.dir.writeFile(io, .{ .sub_path = "themes/policypress/static/draft.png", .data = "" });

    alloc.free(conf.root);
    conf.root = try alloc.dupe(u8, tmp_path);
    conf.is_draft = true;

    const path = (try typst.resolveDraftPng(io, alloc, conf)) orelse return error.NoDraftPng;
    defer alloc.free(path);
    try tst.expect(std.mem.indexOf(u8, path, "themes" ++ std.fs.path.sep_str ++ "policypress") == null);
}

test "draft mode: returns null when no draft.png exists anywhere" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    alloc.free(conf.root);
    conf.root = try alloc.dupe(u8, tmp_path);
    conf.is_draft = true;

    try tst.expectEqual(null, try typst.resolveDraftPng(io, alloc, conf));
}

// --- executableInPath ---

test "executableInPath: sh is present on unix" {
    if (comptime b.os.tag == .windows) return error.SkipZigTest;
    var env = try testEnvMap(tst.allocator);
    defer env.deinit();
    try tst.expect(utils.executableInPath(io, &env, "sh"));
}

test "executableInPath: nonexistent binary returns false" {
    var env = try testEnvMap(tst.allocator);
    defer env.deinit();
    try tst.expect(!utils.executableInPath(io, &env, "pp-test-nonexistent-xyzzy-12345"));
}

// --- Build-time mermaid rendering (src/diagrams.zig, `render-diagrams`) ---
// The site ships no client-side mermaid bundle; the `<pre class="mermaid">`
// placeholder Zola emits is rewritten to inline SVG (pozeiden) at build time.

test "diagrams: mermaid placeholder is rewritten to inline svg" {
    const alloc = tst.allocator;
    // Body arrives HTML-escaped (Zola auto-escapes shortcode bodies), e.g. -->.
    const html = "<p>before</p><pre class=\"mermaid\">\n  graph TD; A--&gt;B\n</pre><p>after</p>";
    const result = try diagrams.rewriteHtml(alloc, html);
    try tst.expect(result != null);
    const r = result.?;
    defer alloc.free(r.html);

    try tst.expectEqual(@as(usize, 1), r.count);
    try tst.expect(std.mem.indexOf(u8, r.html, "<figure class=\"mermaid-diagram\" role=\"img\" aria-label=\"Diagram\">") != null);
    try tst.expect(std.mem.indexOf(u8, r.html, "<svg") != null);
    // The placeholder must be gone (no residual client-render target).
    try tst.expect(std.mem.indexOf(u8, r.html, "<pre class=\"mermaid\">") == null);
    // Surrounding markup is preserved verbatim.
    try tst.expect(std.mem.indexOf(u8, r.html, "<p>before</p>") != null);
    try tst.expect(std.mem.indexOf(u8, r.html, "<p>after</p>") != null);
}

test "diagrams: html without a mermaid block is left unchanged (null)" {
    const alloc = tst.allocator;
    try tst.expect(try diagrams.rewriteHtml(alloc, "<p>no diagrams here</p>") == null);
}

// ── Report PDFs: data-layer tests (control_report.zig) ────────────────────

test "tsc2017.json mirrors tsc2017.yml (control-ID parity)" {
    // data/tsc2017.json is a converted mirror of data/tsc2017.yml (the Zig
    // loader reads only JSON arrays; the web templates read the YAML). Guard
    // against drift: the JSON's control_id set must equal the YAML's
    // top-level keys, which are trivially line-scannable.
    var r = try report.init(io, tst.allocator, "data/tsc2017.json");
    defer r.deinit();
    try tst.expect(r.map.count() >= 61);
    try tst.expect(r.map.contains("CC1.1"));
    try tst.expect(r.map.contains("A1.1"));
    try tst.expect(r.map.contains("P8.1"));

    const yml = try std.Io.Dir.cwd().readFileAlloc(io, "data/tsc2017.yml", tst.allocator, .limited(10_000_000));
    defer tst.allocator.free(yml);
    var yml_keys: usize = 0;
    var lines = std.mem.splitScalar(u8, yml, '\n');
    while (lines.next()) |line| {
        // Top-level keys sit at column 0 and end with ':' (e.g. "CC1.1:").
        if (line.len < 2 or line[0] == ' ' or line[0] == '#') continue;
        if (line[line.len - 1] != ':') continue;
        yml_keys += 1;
        try tst.expect(r.map.contains(line[0 .. line.len - 1]));
    }
    try tst.expectEqual(yml_keys, r.map.count());
}

test "scf.json mirrors scf.yml (control-ID parity)" {
    // Both files are generated together by tools/gen-scf-catalog.py from the
    // pinned scf input (the Zig loader reads only JSON arrays; the web
    // templates read the YAML). Guard against drift: the JSON's control_id
    // set must equal the YAML's `control_id:` entries, whose values are
    // always double-quoted by the generator.
    var r = try report.init(io, tst.allocator, "data/scf.json");
    defer r.deinit();
    try tst.expect(r.map.count() >= 1468);
    try tst.expect(r.map.contains("GOV-01"));
    try tst.expect(r.map.contains("WEB-14"));

    const yml = try std.Io.Dir.cwd().readFileAlloc(io, "data/scf.yml", tst.allocator, .limited(10_000_000));
    defer tst.allocator.free(yml);
    var yml_keys: usize = 0;
    var lines = std.mem.splitScalar(u8, yml, '\n');
    const prefix = "  control_id: \"";
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        if (line.len < prefix.len + 2 or line[line.len - 1] != '"') continue;
        yml_keys += 1;
        try tst.expect(r.map.contains(line[prefix.len .. line.len - 1]));
    }
    try tst.expectEqual(yml_keys, r.map.count());
}

test "coverage: corrected numerator, dedup, draft exclusion, unknown IDs" {
    var r = try report.init(io, tst.allocator, "tests/report-fixtures/report_catalog_scf.json");
    defer r.deinit();
    const cov = try r.coverage(io, "taxonomies.SCF", "tests/report-fixtures/policies");

    try tst.expectEqual(@as(usize, 5), cov.total);
    // GOV-01 (a+b), GOV-02 (a+c) — GOV-03 only in the draft, HRS-02 only in
    // the draft, HRS-01 (b). NOT-A-CONTROL must not add anything.
    try tst.expectEqual(@as(usize, 3), cov.covered);

    // Catalog order preserved.
    try tst.expectEqualStrings("GOV-01", cov.controls[0].control_id);
    try tst.expectEqual(@as(usize, 2), cov.controls[0].policies.len);
    try tst.expectEqualStrings("Alpha Security Policy", cov.controls[0].policies[0]);
    try tst.expectEqualStrings("Bravo Handling Policy", cov.controls[0].policies[1]);

    // pol_a lists GOV-02 twice — deduplicated.
    try tst.expectEqualStrings("GOV-02", cov.controls[1].control_id);
    try tst.expectEqual(@as(usize, 2), cov.controls[1].policies.len);

    // GOV-03 is only tagged by the draft policy: uncovered. It is also declared
    // out of scope by Alpha (extra.scope_exclusions), so it is in the third
    // state — excluded but not covered. The exclusion never inflates `covered`.
    try tst.expectEqualStrings("GOV-03", cov.controls[2].control_id);
    try tst.expectEqual(@as(usize, 0), cov.controls[2].policies.len);
    try tst.expectEqual(@as(usize, 1), cov.excluded);
    try tst.expectEqual(@as(usize, 1), cov.controls[2].excluded_by.len);
    try tst.expectEqualStrings("Alpha Security Policy", cov.controls[2].excluded_by[0]);
    // A covered control carries no exclusion.
    try tst.expectEqual(@as(usize, 0), cov.controls[0].excluded_by.len);
}

test "collectReviewRows: sorted, statuses, missing fields" {
    const rows = try report.collectReviewRows(
        io,
        tst.allocator,
        "tests/report-fixtures/policies",
        .{ .year = 2026, .month = 1, .day = 1 },
    );
    defer report.freeReviewRows(tst.allocator, rows);

    // Draft excluded; four fixtures remain, sorted by last_reviewed then title.
    try tst.expectEqual(@as(usize, 4), rows.len);
    try tst.expectEqualStrings("Bravo Handling Policy", rows[0].title); // 2024-06-01
    try tst.expectEqualStrings("2.0", rows[2].version); // Alpha, newest of two revisions
    try tst.expect(rows[0].days_since.? > 365); // overdue
    // pol_c: no owner, no revisions, 292 days -> due-soon window.
    const charlie = rows[1];
    try tst.expect(charlie.owner == null);
    try tst.expectEqualStrings("", charlie.version);
    try tst.expect(charlie.days_since.? > 365 - 90 and charlie.days_since.? <= 365);
    // pol_d: unparseable date sorts first or last by string; days null.
    var found_unknown = false;
    for (rows) |row| {
        if (row.days_since == null) found_unknown = true;
    }
    try tst.expect(found_unknown);
}

// ── Audit bundle (src/audit.zig) ──────────────────────────────────────────────

test "audit bundle: manifest hashes, newest revision, coverage export" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    conf.date = .{ .year = 2026, .month = 1, .day = 1 };

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(base);

    // One valid policy (the shared fixture) in a scratch policy dir.
    const pol_dir = try std.fs.path.join(alloc, &.{ base, "policies" });
    defer alloc.free(pol_dir);
    try std.Io.Dir.cwd().createDirPath(io, pol_dir);
    const src_md = try std.Io.Dir.cwd().readFileAlloc(io, "src/test/test_policy.md", alloc, .limited(1 << 20));
    defer alloc.free(src_md);
    {
        const p = try std.fs.path.join(alloc, &.{ pol_dir, "test_policy.md" });
        defer alloc.free(p);
        const f = try std.Io.Dir.cwd().createFile(io, p, .{ .truncate = true });
        defer f.close(io);
        try f.writeStreamingAll(io, src_md);
    }

    // A fake "PDF" under the canonical output name (title Test Policy, newest
    // revision v1.1) so the manifest has bytes to hash.
    const pdf_dir = try std.fs.path.join(alloc, &.{ base, "pdfs" });
    defer alloc.free(pdf_dir);
    try std.Io.Dir.cwd().createDirPath(io, pdf_dir);
    const fake_pdf = "fake pdf bytes";
    {
        const p = try std.fs.path.join(alloc, &.{ pdf_dir, "Test_Policy_-_v1.1.pdf" });
        defer alloc.free(p);
        const f = try std.Io.Dir.cwd().createFile(io, p, .{ .truncate = true });
        defer f.close(io);
        try f.writeStreamingAll(io, fake_pdf);
    }

    alloc.free(conf.policy_dir);
    conf.policy_dir = try alloc.dupe(u8, pol_dir);
    conf.build_dir = pdf_dir;

    const audit_dir = try std.fs.path.join(alloc, &.{ base, "audit" });
    defer alloc.free(audit_dir);
    try audit.writeBundle(io, alloc, conf, audit_dir, "9.9.9-test");

    // ── manifest.json ────────────────────────────────────────────────────────
    {
        const p = try std.fs.path.join(alloc, &.{ audit_dir, "manifest.json" });
        defer alloc.free(p);
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, p, alloc, .limited(1 << 20));
        defer alloc.free(bytes);
        const parsed = try std.json.parseFromSlice(std.json.Value, alloc, bytes, .{});
        defer parsed.deinit();
        const root = parsed.value.object;
        try tst.expectEqualStrings("policypress/audit-manifest/v1", root.get("schema").?.string);
        try tst.expectEqualStrings("9.9.9-test", root.get("policypress_version").?.string);
        try tst.expectEqualStrings("2026-01-01", root.get("generated_at").?.string);
        try tst.expectEqual(false, root.get("build").?.object.get("redact").?.bool);
        const pols = root.get("policies").?.array.items;
        try tst.expectEqual(@as(usize, 1), pols.len);
        const pol = pols[0].object;
        try tst.expectEqualStrings("Test Policy", pol.get("title").?.string);
        try tst.expectEqualStrings("1.1", pol.get("version").?.string);
        try tst.expectEqualStrings("Ada Byrne", pol.get("approved_by").?.string);
        try tst.expectEqualStrings("SC2", pol.get("owner").?.string);
        try tst.expectEqualStrings("pdfs/Test_Policy_-_v1.1.pdf", pol.get("pdf").?.string);

        var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(fake_pdf, &digest, .{});
        const expected_sha = try std.fmt.allocPrint(alloc, "{x}", .{&digest});
        defer alloc.free(expected_sha);
        try tst.expectEqualStrings(expected_sha, pol.get("pdf_sha256").?.string);
    }

    // ── revisions.json: both revisions of the fixture, flattened ────────────
    {
        const p = try std.fs.path.join(alloc, &.{ audit_dir, "revisions.json" });
        defer alloc.free(p);
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, p, alloc, .limited(1 << 20));
        defer alloc.free(bytes);
        const parsed = try std.json.parseFromSlice(std.json.Value, alloc, bytes, .{});
        defer parsed.deinit();
        const revs = parsed.value.object.get("revisions").?.array.items;
        try tst.expectEqual(@as(usize, 2), revs.len);
        try tst.expectEqualStrings("1.1", revs[0].object.get("version").?.string);
    }

    // ── coverage.json: real catalogs at the repo root; HRS-05 covered ───────
    {
        const p = try std.fs.path.join(alloc, &.{ audit_dir, "coverage.json" });
        defer alloc.free(p);
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, p, alloc, .limited(16 << 20));
        defer alloc.free(bytes);
        const parsed = try std.json.parseFromSlice(std.json.Value, alloc, bytes, .{});
        defer parsed.deinit();
        const fws = parsed.value.object.get("frameworks").?.array.items;
        try tst.expectEqual(@as(usize, 2), fws.len);
        const scf = fws[0].object;
        try tst.expectEqualStrings("SCF", scf.get("id").?.string);
        try tst.expect(scf.get("covered").?.integer >= 1);
        try tst.expect(scf.get("total").?.integer >= 1468);

        // Additive per-control excluded_by (#165), schema string unchanged. The
        // fixture policy declares PES-01 out of scope, so that control's
        // excluded_by lists the policy title; a covered control (HRS-05) has an
        // empty excluded_by. Every control carries the key (additive schema).
        var saw_pes01 = false;
        var saw_hrs05 = false;
        for (scf.get("controls").?.array.items) |cv| {
            const c = cv.object;
            const cid = c.get("control_id").?.string;
            const excl = c.get("excluded_by").?.array.items;
            if (std.mem.eql(u8, cid, "PES-01")) {
                saw_pes01 = true;
                try tst.expectEqual(@as(usize, 1), excl.len);
                try tst.expectEqualStrings("Test Policy", excl[0].string);
            } else if (std.mem.eql(u8, cid, "HRS-05")) {
                saw_hrs05 = true;
                try tst.expectEqual(@as(usize, 0), excl.len);
            }
        }
        try tst.expect(saw_pes01);
        try tst.expect(saw_hrs05);
    }

    // ── join.json gating: NOT written without a praxis_join ─────────────────
    // TestConfig configures no praxis_join, so the join facet must be absent —
    // the bundle is exactly as it was before the facet existed.
    {
        const p = try std.fs.path.join(alloc, &.{ audit_dir, "join.json" });
        defer alloc.free(p);
        const exists = if (std.Io.Dir.cwd().access(io, p, .{})) |_| true else |_| false;
        try tst.expect(!exists);
    }
}

test "audit bundle: praxis join facet (join.json)" {
    const alloc = tst.allocator;
    var conf = try config.load(io, alloc, TestConfig);
    defer conf.deinit(alloc);
    conf.date = .{ .year = 2026, .month = 1, .day = 1 };
    // Enable the facet. The path is resolved relative to conf.root (the repo
    // root under test), matching main.zig's join-path resolution.
    conf.praxis_join = "data/praxis-join.json";

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(base);

    const pol_dir = try std.fs.path.join(alloc, &.{ base, "policies" });
    defer alloc.free(pol_dir);
    try std.Io.Dir.cwd().createDirPath(io, pol_dir);
    const pdf_dir = try std.fs.path.join(alloc, &.{ base, "pdfs" });
    defer alloc.free(pdf_dir);
    try std.Io.Dir.cwd().createDirPath(io, pdf_dir);

    // Policy 1: the shared fixture — covers HRS-05.* (all in the spine) and
    // declares PES-01 (also in the spine) out of scope.
    const src_md = try std.Io.Dir.cwd().readFileAlloc(io, "src/test/test_policy.md", alloc, .limited(1 << 20));
    defer alloc.free(src_md);
    try writeFileAt(alloc, pol_dir, "test_policy.md", src_md);
    try writeFileAt(alloc, pdf_dir, "Test_Policy_-_v1.1.pdf", "fake pdf bytes");

    // Policy 2: COVERS PES-01, which policy 1 excludes — a cross-policy conflict
    // (declared_by AND excluded_by both non-empty) and, via the tie-break, a
    // spine control that counts as covered despite the exclusion.
    const conflict_md =
        \\---
        \\title: "Conflict Test Policy"
        \\date: 2024-11-13
        \\taxonomies:
        \\  SCF:
        \\    - PES-01
        \\extra:
        \\  owner: SC2
        \\  last_reviewed: 2025-02-24
        \\  major_revisions:
        \\    - version: "1.0"
        \\      date: 2024-11-13
        \\      approved_by: Ada Byrne
        \\      description: Initial version.
        \\---
        \\
        \\## Body
        \\
        \\Content.
        \\
    ;
    try writeFileAt(alloc, pol_dir, "conflict_test.md", conflict_md);
    try writeFileAt(alloc, pdf_dir, "Conflict_Test_Policy_-_v1.0.pdf", "fake pdf bytes");

    alloc.free(conf.policy_dir);
    conf.policy_dir = try alloc.dupe(u8, pol_dir);
    conf.build_dir = pdf_dir;

    const audit_dir = try std.fs.path.join(alloc, &.{ base, "audit" });
    defer alloc.free(audit_dir);
    try audit.writeBundle(io, alloc, conf, audit_dir, "9.9.9-test");

    const p = try std.fs.path.join(alloc, &.{ audit_dir, "join.json" });
    defer alloc.free(p);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, p, alloc, .limited(16 << 20));
    defer alloc.free(bytes);
    const parsed = try std.json.parseFromSlice(std.json.Value, alloc, bytes, .{});
    defer parsed.deinit();
    const root = parsed.value.object;

    // Schema + provenance carried from the loaded join.
    try tst.expectEqualStrings("policypress/audit-join/v1", root.get("schema").?.string);
    try tst.expectEqualStrings("2026-01-01", root.get("generated_at").?.string);
    const prov = root.get("praxis").?.object;
    try tst.expectEqualStrings("2026-07-22", prov.get("generated_at").?.string);
    try tst.expectEqualStrings("demo-fixture", prov.get("source_rev").?.string);
    try tst.expectEqualStrings("2026.1.1", prov.get("scf_version").?.string);

    // Summary math identity: covered + excluded + unaddressed == total.
    const sm = root.get("summary").?.object;
    const total = sm.get("spine_total").?.integer;
    const covered = sm.get("spine_covered").?.integer;
    const excluded = sm.get("spine_excluded").?.integer;
    const unaddressed = sm.get("spine_unaddressed").?.integer;
    try tst.expectEqual(@as(i64, 23), total); // the demo fixture has 23 spine ids
    try tst.expectEqual(total, covered + excluded + unaddressed);
    // HRS-05.* (6) plus PES-01 (covered by the conflict policy, tie-break) = 7.
    try tst.expectEqual(@as(i64, 7), covered);
    // PES-01 is covered, so it does NOT count toward excluded.
    try tst.expectEqual(@as(i64, 0), excluded);

    // Walk the control rows for the three representative states.
    var saw_pes01 = false;
    var saw_hrs05 = false;
    var saw_mon02 = false;
    for (root.get("controls").?.array.items) |cv| {
        const c = cv.object;
        const cid = c.get("id").?.string;
        const in_spine = c.get("in_praxis_spine").?.bool;
        const decl = c.get("declared_by").?.array.items;
        const excl = c.get("excluded_by").?.array.items;
        const conflict = c.get("conflict").?.bool;
        if (std.mem.eql(u8, cid, "PES-01")) {
            saw_pes01 = true;
            try tst.expect(in_spine); // in-spine AND excluded
            try tst.expectEqual(@as(usize, 1), decl.len);
            try tst.expectEqualStrings("Conflict Test Policy", decl[0].string);
            try tst.expectEqual(@as(usize, 1), excl.len);
            try tst.expectEqualStrings("Test Policy", excl[0].string);
            try tst.expect(conflict); // the cross-policy tension
        } else if (std.mem.eql(u8, cid, "HRS-05")) {
            saw_hrs05 = true;
            try tst.expect(in_spine);
            try tst.expectEqual(@as(usize, 1), decl.len);
            try tst.expectEqualStrings("Test Policy", decl[0].string);
            try tst.expectEqual(@as(usize, 0), excl.len);
            try tst.expect(!conflict);
        } else if (std.mem.eql(u8, cid, "MON-02")) {
            // A gap id: in the spine but neither covered nor excluded.
            saw_mon02 = true;
            try tst.expect(in_spine);
            try tst.expectEqual(@as(usize, 0), decl.len);
            try tst.expectEqual(@as(usize, 0), excl.len);
            try tst.expect(!conflict);
        }
    }
    try tst.expect(saw_pes01);
    try tst.expect(saw_hrs05);
    try tst.expect(saw_mon02);
}

// ── praxis join loader (src/praxis_join.zig) ─────────────────────────────────

test "praxis join: loads the committed demo fixture" {
    const alloc = tst.allocator;
    var join = try praxis_join.PraxisJoin.load(io, alloc, "data/praxis-join.json");
    defer join.deinit();

    // Provenance carried through for auditors.
    try tst.expectEqualStrings("2026-07-22", join.generated_at);
    try tst.expectEqualStrings("demo-fixture", join.source_rev);
    try tst.expectEqualStrings("2026.1.1", join.scf_version);
    try tst.expectEqual(@as(usize, 1), join.organizational_families.len);
    try tst.expectEqualStrings("GOV", join.organizational_families[0]);

    // contains() positive: a demo-tagged id, a dotted sub-control, an
    // uncovered gap id, and the future scope-exclusion id are all in the spine.
    try tst.expect(join.contains("GOV-01"));
    try tst.expect(join.contains("HRS-05.1"));
    try tst.expect(join.contains("MON-02")); // uncovered gap id
    try tst.expect(join.contains("PES-01")); // future scope-exclusion id
    // contains() negative: a valid SCF id the fixture deliberately omits.
    try tst.expect(!join.contains("AST-01"));
}

test "praxis join: wrong schema string is a hard, distinct error" {
    const alloc = tst.allocator;
    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    const bad =
        \\{ "schema": "policypress/praxis-join/v2",
        \\  "generated_at": "2026-07-22",
        \\  "source": { "rev": "x", "scf_version": "2026.1.1" },
        \\  "organizational_families": ["GOV"], "ids": ["GOV-01"] }
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "bad_schema.json", .data = bad });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "bad_schema.json" });
    defer alloc.free(p);

    try tst.expectError(error.SchemaMismatch, praxis_join.PraxisJoin.load(io, alloc, p));
}

test "praxis join: missing schema field is a hard, distinct error" {
    const alloc = tst.allocator;
    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // Valid JSON, plausible payload — but no `schema`, so it must not pass.
    const bad =
        \\{ "generated_at": "2026-07-22",
        \\  "organizational_families": ["GOV"], "ids": ["GOV-01"] }
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "no_schema.json", .data = bad });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "no_schema.json" });
    defer alloc.free(p);

    try tst.expectError(error.MissingSchema, praxis_join.PraxisJoin.load(io, alloc, p));
}

// ── Control-ID join (src/controls.zig) ────────────────────────────────────────

/// A ControlJoin over the committed fixtures: catalog IAC-01/DCH-01/NET-02,
/// spine {IAC-01, NET-02}, library = two control fixture policies — the primary
/// ("Access Control Test Policy", tags IAC-01 + DCH-01) and a related policy
/// ("Access Control Standard", tags IAC-01), so "See also" cross-references have
/// another policy to point at.
fn fixtureControlJoin(alloc: Allocator) !controls.ControlJoin {
    return controls.ControlJoin.init(
        io,
        alloc,
        "src/test/controls_catalog.json",
        "src/test/controls_tsc_catalog.json",
        "src/test/controls_join.json",
        &.{ "src/test/test_policy_controls.md", "src/test/test_policy_controls_related.md" },
    );
}

/// The primary fixture policy, used as the "self" excluded from its own
/// "See also" cross-references.
const fixture_self = "src/test/test_policy_controls.md";

test "controls: resolveFootnote — praxis-free, 'See also' lists OTHER covering policies (excludes self)" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    // IAC-01 is tagged by the primary fixture (self) and the related policy.
    // Rendered from the primary fixture, "See also" names only the related one.
    const md = (try cj.resolveFootnote(alloc, "IAC-01", fixture_self)).?;
    defer alloc.free(md);
    try tst.expect(std.mem.startsWith(u8, md, "IAC-01 \u{2014} Identity & Access Management."));
    try tst.expect(std.mem.indexOf(u8, md, "See also: Access Control Standard.") != null);
    // No praxis clause, and the policy never lists itself.
    try tst.expect(std.mem.indexOf(u8, md, "praxis") == null);
    try tst.expect(std.mem.indexOf(u8, md, "Access Control Test Policy") == null);
}

test "controls: resolveFootnote — 'See also' omitted when self is the only coverer" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    // DCH-01 is tagged only by the primary fixture; excluding self leaves no
    // other policy, so the clause is dropped entirely — just id + title.
    const md = (try cj.resolveFootnote(alloc, "DCH-01", fixture_self)).?;
    defer alloc.free(md);
    try tst.expectEqualStrings("DCH-01 \u{2014} Data Protection.", md);
}

test "controls: resolveFootnote — null self_path lists every covering policy, sorted" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    // Document-agnostic resolver: both policies covering IAC-01 are listed.
    const md = (try cj.resolveFootnote(alloc, "IAC-01", null)).?;
    defer alloc.free(md);
    try tst.expect(std.mem.indexOf(u8, md, "See also: Access Control Standard, Access Control Test Policy.") != null);
    try tst.expect(std.mem.indexOf(u8, md, "praxis") == null);
}

test "controls: resolveFootnote — an uncovered control has no 'See also' clause" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    // No policy tags NET-02, so the footnote is just id + title (no praxis, even
    // though NET-02 is in the spine).
    const md = (try cj.resolveFootnote(alloc, "NET-02", fixture_self)).?;
    defer alloc.free(md);
    try tst.expectEqualStrings("NET-02 \u{2014} Layered Network Defenses.", md);
}

test "controls: resolveFootnote — a non-control label returns null" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    try tst.expect((try cj.resolveFootnote(alloc, "not-a-control", fixture_self)) == null);
    try tst.expect((try cj.resolveFootnote(alloc, "1", fixture_self)) == null);
}

test "controls: resolveFootnote — a configured join never adds a praxis clause" {
    const alloc = tst.allocator;
    // Even with a praxis join loaded, the footnote body stays praxis-agnostic
    // (#172/#174): spine membership lives on the web badges / annex / join.json,
    // not inline in every footnote.
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    const md = (try cj.resolveFootnote(alloc, "IAC-01", null)).?;
    defer alloc.free(md);
    try tst.expect(std.mem.indexOf(u8, md, "praxis") == null);
    try tst.expect(std.mem.indexOf(u8, md, "in control spine") == null);
}

test "controls: resolveFootnote — no catalog omits the title clause" {
    const alloc = tst.allocator;
    var cj = try controls.ControlJoin.init(
        io,
        alloc,
        null, // no catalog
        null, // no TSC catalog
        "src/test/controls_join.json",
        &.{ "src/test/test_policy_controls.md", "src/test/test_policy_controls_related.md" },
    );
    defer cj.deinit();

    const md = (try cj.resolveFootnote(alloc, "IAC-01", fixture_self)).?;
    defer alloc.free(md);
    // Just the id (no "— title"), then the See-also clause for the other policy.
    try tst.expect(std.mem.startsWith(u8, md, "IAC-01."));
    try tst.expect(std.mem.indexOf(u8, md, "\u{2014}") == null);
    try tst.expect(std.mem.indexOf(u8, md, "See also: Access Control Standard.") != null);
}

test "controls: reviewControlRefs — clean fixture is none" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();
    try tst.expectEqual(config.IssueKind.none, cj.reviewControlRefs(io, alloc, "src/test/test_policy_controls.md", false));
}

test "controls: reviewControlRefs — unknown id in taxonomies.SCF is critical" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // GOV-99 is well-formed but not in the fixture catalog.
    const md =
        \\---
        \\title: "Bad Taxonomy"
        \\taxonomies:
        \\  SCF:
        \\    - GOV-99
        \\---
        \\Body.
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "bad_tax.md", .data = md });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "bad_tax.md" });
    defer alloc.free(p);

    try tst.expectEqual(config.IssueKind.critical, cj.reviewControlRefs(io, alloc, p, false));
}

test "controls: reviewControlRefs — malformed shortcode is critical" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // Lowercase, single-digit id: the strict pattern rejects it, leaving a
    // control( opener the reviewer flags.
    const md =
        \\---
        \\title: "Bad Shortcode"
        \\---
        \\Access {{ control(id="iac-1") }} enforced.
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "bad_sc.md", .data = md });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "bad_sc.md" });
    defer alloc.free(p);

    try tst.expectEqual(config.IssueKind.critical, cj.reviewControlRefs(io, alloc, p, false));
}

test "controls: reviewControlRefs — a control-shaped dangling raw ref is critical (native footnotes off)" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // Author typed a raw footnote reference instead of the shortcode.
    const md =
        \\---
        \\title: "Raw Footnote"
        \\---
        \\Access is least-privilege [^IAC-01] enforced.
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "raw_fn.md", .data = md });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "raw_fn.md" });
    defer alloc.free(p);

    try tst.expectEqual(config.IssueKind.critical, cj.reviewControlRefs(io, alloc, p, false));
}

test "controls: reviewControlRefs — native footnotes on: a known dangling id is clean (#173)" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // IAC-01 is a known catalog id. With control_footnotes enabled the pre-Zola
    // stage-site pass synthesises the web definition, so a bare [^IAC-01] is fine
    // (the PDF pipeline already resolves it).
    const md =
        \\---
        \\title: "Native Footnote"
        \\---
        \\Access is least-privilege [^IAC-01] enforced.
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "native_fn.md", .data = md });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "native_fn.md" });
    defer alloc.free(p);

    try tst.expectEqual(config.IssueKind.none, cj.reviewControlRefs(io, alloc, p, true));
}

test "controls: reviewControlRefs — native footnotes on: an unknown well-formed id is still critical (#173)" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // ZZZ-99 is control-shaped but not in the fixture catalog: a typo would be
    // dead text on the web, so it stays critical even with native footnotes on.
    const md =
        \\---
        \\title: "Typo Footnote"
        \\---
        \\A typo reference [^ZZZ-99] here.
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "typo_fn.md", .data = md });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "typo_fn.md" });
    defer alloc.free(p);

    try tst.expectEqual(config.IssueKind.critical, cj.reviewControlRefs(io, alloc, p, true));
}

test "controls: reviewControlRefs — native footnotes on, no catalog: a control-shaped id is clean (#173)" {
    const alloc = tst.allocator;
    // With no catalog to check against, the unknown-id typo check is skipped, so
    // a control-shaped dangling ref is accepted (mirrors reviewShortcodes and
    // reviewTaxonomy, which also skip unknown-id checks with no catalog).
    var cj = try controls.ControlJoin.init(
        io,
        alloc,
        null, // no catalog
        null, // no TSC catalog
        null, // no praxis join
        &.{},
    );
    defer cj.deinit();

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    const md =
        \\---
        \\title: "No Catalog Footnote"
        \\---
        \\Reference [^IAC-01] with no catalog loaded.
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "nocat_fn.md", .data = md });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "nocat_fn.md" });
    defer alloc.free(p);

    try tst.expectEqual(config.IssueKind.none, cj.reviewControlRefs(io, alloc, p, true));
}

test "controls: annexProvider resolves catalog titles (praxis-agnostic)" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    const prov = cj.annexProvider();

    // SCF: title from the catalog. The annex carries no praxis-spine column —
    // spine membership is an optional overlay (web badges + join.json), not
    // part of this core table.
    const iac = prov.lookup(.scf, "IAC-01");
    try tst.expectEqualStrings("Identity & Access Management", iac.title.?);
    const dch = prov.lookup(.scf, "DCH-01");
    try tst.expectEqualStrings("Data Protection", dch.title.?);

    // TSC 2017: title from the TSC catalog.
    const cc = prov.lookup(.tsc2017, "CC1.1");
    try tst.expectEqualStrings("Integrity and Ethics", cc.title.?);

    // Unknown id → null title (annex shows the id alone).
    try tst.expect(prov.lookup(.scf, "ZZZ-99").title == null);
}

test "controls: reviewControlRefs — a scope exclusion missing a reason is critical" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // NET-02 is a valid catalog id not covered by the library policy, so the
    // only problem is the missing reason (isolates the rule from the advisory).
    const md =
        \\---
        \\title: "No Reason"
        \\extra:
        \\  scope_exclusions:
        \\    - id: NET-02
        \\---
        \\Body.
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "no_reason.md", .data = md });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "no_reason.md" });
    defer alloc.free(p);

    try tst.expectEqual(config.IssueKind.critical, cj.reviewControlRefs(io, alloc, p, false));
}

test "controls: reviewControlRefs — an unknown scope-exclusion id is critical" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // GOV-99 is well-formed but not in the fixture catalog.
    const md =
        \\---
        \\title: "Unknown Exclusion"
        \\extra:
        \\  scope_exclusions:
        \\    - id: GOV-99
        \\      reason: "x"
        \\---
        \\Body.
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "unknown_excl.md", .data = md });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "unknown_excl.md" });
    defer alloc.free(p);

    try tst.expectEqual(config.IssueKind.critical, cj.reviewControlRefs(io, alloc, p, false));
}

test "controls: reviewControlRefs — same-policy cover+exclude is critical" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // DCH-01 is both claimed (taxonomies.SCF) and disclaimed (scope_exclusions).
    const md =
        \\---
        \\title: "Contradiction"
        \\taxonomies:
        \\  SCF:
        \\    - DCH-01
        \\extra:
        \\  scope_exclusions:
        \\    - id: DCH-01
        \\      reason: "x"
        \\---
        \\Body.
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "contradiction.md", .data = md });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "contradiction.md" });
    defer alloc.free(p);

    try tst.expectEqual(config.IssueKind.critical, cj.reviewControlRefs(io, alloc, p, false));
}

test "controls: reviewControlRefs — excluding a control another policy covers is advisory" {
    const alloc = tst.allocator;
    var cj = try fixtureControlJoin(alloc);
    defer cj.deinit();

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmpAbsPath(alloc, &tmp);
    defer alloc.free(tmp_path);

    // IAC-01 is covered by the library policy ("Access Control Test Policy") but
    // declared out of scope here — a legitimate governance tension, so advisory
    // (not critical). The exclusion is otherwise well-formed.
    const md =
        \\---
        \\title: "Excludes A Covered Control"
        \\extra:
        \\  scope_exclusions:
        \\    - id: IAC-01
        \\      reason: "Handled by the parent entity."
        \\---
        \\Body.
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "cross_conflict.md", .data = md });
    const p = try std.fs.path.join(alloc, &.{ tmp_path, "cross_conflict.md" });
    defer alloc.free(p);

    try tst.expectEqual(config.IssueKind.advisory, cj.reviewControlRefs(io, alloc, p, false));
}

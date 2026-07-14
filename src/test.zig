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
    // redact_web is web-only (Zola templates); PDF redaction comes solely
    // from --redact/--no-redact. TestConfig sets redact_web = true, so this
    // pins the decoupling (#115).
    try tst.expect(!conf.redact);
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
    typst.compile(io, &env, tst.allocator, conf, "src/test/test_policy.md") catch |e| {
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
    // try tst.expect(j.value.object.count() >= 1239); // test for number of controls read as of 10/2/2025
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

const diagrams = @import("diagrams.zig");

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

//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const b = @import("builtin");

const config = @import("config").Config;
const pandoc = @import("pandoc");
const report = @import("reports");
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

test {
    _ = utils;
    _ = zigmark;
    _ = pandoc;
    _ = report;
    tst.refAllDeclsRecursive(@This());
}

test "config loading and validation" {
    const alloc = tst.allocator;
    var env = try std.process.getEnvMap(alloc);
    defer env.deinit();
    var conf = try config.load(alloc, TestConfig);
    defer conf.deinit(alloc);
    alloc.free(conf.content_dir);
    conf.content_dir = try std.fs.path.join(alloc, &.{
        conf.root,
        "src",
        "test",
    });
    alloc.free(conf.policy_dir);
    conf.policy_dir = try alloc.dupe(u8, conf.content_dir);

    try conf.validatePolicyFiles(alloc);
}

test "policy processing" {
    const test_policy_file = try std.fs.cwd().openFile("src/test/test_policy.md", .{});
    defer test_policy_file.close();
    const test_policy = try test_policy_file.readToEndAlloc(tst.allocator, std.math.maxInt(usize));
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

    var t1 = Array(u8){};
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
    try tst.expectEqualStrings("Test_Policy_(Redacted)_-_v1.1.pdf", out_file_name);

    try utils.replace_zola_at(tst.allocator, &t1, "https://test.lol");
    try utils.replace_org(tst.allocator, &t1, "loltest");
    try utils.replace_mermaid(tst.allocator, &t1);
    try utils.redact(tst.allocator, &t1, true);

    try tst.expect(std.mem.indexOf(u8, t1.items, "~~~mermaid") != null);
    try tst.expect(std.mem.indexOf(u8, t1.items, &[_]u8{'_'} ** 10) != null);
    try tst.expectEqual(3, std.mem.count(u8, t1.items, "https://test.lol/"));
    try tst.expectEqual(0, std.mem.count(u8, t1.items, "{% end %}"));
}
test "pdf rendering" {
    if (!pandoc.executableInPath("xelatex")) return error.SkipZigTest;
    var args = Array([]u8){};
    var env = try std.process.getEnvMap(tst.allocator);
    defer env.deinit();

    var tmp = tst.tmpDir(.{});

    const alloc = tst.allocator;
    var conf = try config.load(alloc, TestConfig);
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
    conf.build_dir = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(conf.build_dir);

    try pandoc.create_global_args(tst.allocator, &args, conf);
    defer pandoc.destroy_global_args(tst.allocator, &args);
    // Use a mermaid-free fixture so the test works in the Nix sandbox
    // (Chrome/user-namespaces are unavailable there). Mermaid shortcode
    // transformation is already covered by the "policy processing" test.
    const md = utils.MDFile{ .path = "src/test/test_policy_render.md" };
    pandoc.process_md_file(tst.allocator, md, args, conf) catch |e| {
        std.debug.print("Test Policy Pandoc Call Failed! \nConfig:{f}\n", .{conf});
        return e;
    };

    // Verify the PDF was actually written to the output directory.
    // Re-open with iterate permission; the tmpDir handle lacks it by default.
    var out_dir = try std.fs.openDirAbsolute(conf.build_dir, .{ .iterate = true });
    defer out_dir.close();
    var pdf_found = false;
    var dir_iter = out_dir.iterate();
    while (try dir_iter.next()) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".pdf")) {
            pdf_found = true;
            break;
        }
    }
    try tst.expect(pdf_found);

    tmp.cleanup();
}

test "report generation" {

    // var env = try std.process.getEnvMap(tst.allocator);
    // defer env.deinit();

    // var tmp = tst.tmpDir(.{});
    // const builddir = try tmp.dir.realpathAlloc(tst.allocator, ".");
    // defer tst.allocator.free(builddir);

    // const c_file = try std.fs.cwd().realpathAlloc(tst.allocator, "data/scf.json");
    // defer tst.allocator.free(c_file);

    // const c_path = try std.fs.cwd().realpathAlloc(tst.allocator, ".");
    // const p_path = try std.fs.path.join(tst.allocator, &.{ c_path, "content/policies" });
    // defer tst.allocator.free(c_path);
    // defer tst.allocator.free(p_path);

    // var f = try report.init(tst.allocator, c_file);
    // defer f.deinit();

    // const rep = try f.report(p_path);
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
    const tmp_path = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(tmp_path);

    try tmp.dir.writeFile(.{ .sub_path = "policy.md", .data = "content" });
    const src_path = try std.fs.path.join(alloc, &.{ tmp_path, "policy.md" });
    defer alloc.free(src_path);

    try tst.expect(!utils.stampIsNewer(src_path, tmp_path, alloc));
}

test "stamp: writeStamp → stampIsNewer returns true" {
    const alloc = tst.allocator;
    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(tmp_path);

    try tmp.dir.writeFile(.{ .sub_path = "policy.md", .data = "content" });
    const src_path = try std.fs.path.join(alloc, &.{ tmp_path, "policy.md" });
    defer alloc.free(src_path);

    utils.writeStamp(alloc, tmp_path, src_path);

    // Set stamp mtime to 2 s in the future so it is definitely newer.
    const stamp_path = try std.fs.path.join(alloc, &.{ tmp_path, "policy" });
    defer alloc.free(stamp_path);
    const stamp_file = try std.fs.cwd().openFile(stamp_path, .{ .mode = .read_write });
    defer stamp_file.close();
    const now = std.time.nanoTimestamp();
    try stamp_file.updateTimes(now, now + 2_000_000_000);

    try tst.expect(utils.stampIsNewer(src_path, tmp_path, alloc));
}

test "stamp: writeStamp creates file with correct stem" {
    const alloc = tst.allocator;
    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(tmp_path);

    try tmp.dir.writeFile(.{ .sub_path = "access-control.md", .data = "body" });
    const src_path = try std.fs.path.join(alloc, &.{ tmp_path, "access-control.md" });
    defer alloc.free(src_path);

    try tst.expect(!utils.stampIsNewer(src_path, tmp_path, alloc));
    utils.writeStamp(alloc, tmp_path, src_path);

    const stem_path = try std.fs.path.join(alloc, &.{ tmp_path, "access-control" });
    defer alloc.free(stem_path);
    try std.fs.accessAbsolute(stem_path, .{});
}

// ============================================================
// Issue #67: Full Pipeline Tests
// ============================================================

// --- Bad Config → Clear Error ---

test "bad config: missing extra section" {
    try tst.expectError(
        error.NoExtraInZolaConfig,
        config.load(tst.allocator, "base_url = \"http://localhost\""),
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
    try tst.expectError(error.NoLogoInExtra, config.load(tst.allocator, bad));
}

test "bad config: missing organization" {
    const bad =
        \\base_url = "http://localhost"
        \\[extra.policypress]
        \\logo = "logo.png"
        \\pdf_color = "#000"
        \\policy_dir = "."
    ;
    try tst.expectError(error.NoOrganizationInExtra, config.load(tst.allocator, bad));
}

test "bad config: missing pdf_color" {
    const bad =
        \\base_url = "http://localhost"
        \\[extra.policypress]
        \\logo = "logo.png"
        \\organization = "ACME"
        \\policy_dir = "."
    ;
    try tst.expectError(error.NoPDFColorInExtra, config.load(tst.allocator, bad));
}

test "bad config: missing base_url" {
    const bad =
        \\[extra.policypress]
        \\logo = "logo.png"
        \\organization = "ACME"
        \\pdf_color = "#000"
        \\policy_dir = "."
    ;
    try tst.expectError(error.NoBaseUrlInZolaConfig, config.load(tst.allocator, bad));
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
    var arr = Array(u8){};
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
    var arr = Array(u8){};
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
    var arr = Array(u8){};
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
    var conf = try config.load(alloc, TestConfig);
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
    var conf = try config.load(alloc, TestConfig);
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
    var conf = try config.load(alloc, TestConfig);
    defer conf.deinit(alloc);
    try tst.expectError(error.NoApprovalForRevision, conf.validateFrontMatter(fm));
}

// --- Draft Mode Adds Watermark ---

test "draft mode: pandoc args include page-background flags" {
    const alloc = tst.allocator;
    var args = Array([]u8){};
    var conf = try config.load(alloc, TestConfig);
    defer conf.deinit(alloc);
    alloc.free(conf.content_dir);
    conf.content_dir = try std.fs.path.join(alloc, &.{ conf.root, "src", "test" });
    alloc.free(conf.policy_dir);
    conf.policy_dir = try alloc.dupe(u8, conf.content_dir);

    conf.is_draft = true;
    try pandoc.create_global_args(alloc, &args, conf);
    defer pandoc.destroy_global_args(alloc, &args);

    var found_bg = false;
    var found_opacity = false;
    for (args.items) |arg| {
        if (std.mem.indexOf(u8, arg, "page-background=") != null) found_bg = true;
        if (std.mem.indexOf(u8, arg, "page-background-opacity=") != null) found_opacity = true;
    }
    try tst.expect(found_bg);
    try tst.expect(found_opacity);
}

test "non-draft mode: pandoc args exclude page-background flags" {
    const alloc = tst.allocator;
    var args = Array([]u8){};
    var conf = try config.load(alloc, TestConfig);
    defer conf.deinit(alloc);
    alloc.free(conf.content_dir);
    conf.content_dir = try std.fs.path.join(alloc, &.{ conf.root, "src", "test" });
    alloc.free(conf.policy_dir);
    conf.policy_dir = try alloc.dupe(u8, conf.content_dir);

    conf.is_draft = false;
    try pandoc.create_global_args(alloc, &args, conf);
    defer pandoc.destroy_global_args(alloc, &args);

    for (args.items) |arg| {
        try tst.expect(std.mem.indexOf(u8, arg, "page-background=") == null);
    }
}

// --- Redact Mode Removes Sensitive Content ---
// Core redaction behaviour is covered by the "Redaction" test in utils.zig.
// This test confirms the pipeline wires it correctly: get_metadata returns a
// "(Redacted)" title and the content buffer has no raw redact shortcodes left.

test "redact mode: title suffix and content scrubbed" {
    const alloc = tst.allocator;
    const test_policy_file = try std.fs.cwd().openFile("src/test/test_policy.md", .{});
    defer test_policy_file.close();
    const raw = try test_policy_file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(raw);

    var contents = Array(u8){};
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
    // Redacted blocks become underscores, not visible text.
    try tst.expect(std.mem.indexOf(u8, contents.items, &[_]u8{'_'} ** 10) != null);
}

// --- draft.png path resolution ---

// Helper: find the page-background= value among pandoc args.
fn findPageBackground(args: Array([]u8)) ?[]const u8 {
    for (args.items) |arg| {
        if (std.mem.startsWith(u8, arg, "page-background="))
            return arg["page-background=".len..];
    }
    return null;
}

test "draft mode: uses site-root static/draft.png when present" {
    const alloc = tst.allocator;
    var args = Array([]u8){};
    var conf = try config.load(alloc, TestConfig);
    defer conf.deinit(alloc);

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(tmp_path);
    try tmp.dir.makePath("static");
    try tmp.dir.writeFile(.{ .sub_path = "static/draft.png", .data = "" });

    alloc.free(conf.root);
    conf.root = try alloc.dupe(u8, tmp_path);
    conf.is_draft = true;
    try pandoc.create_global_args(alloc, &args, conf);
    defer pandoc.destroy_global_args(alloc, &args);

    const path = findPageBackground(args) orelse return error.NoBgArg;
    // Must point at the site-root copy, not the theme fallback.
    try tst.expect(std.mem.indexOf(u8, path, "static" ++ std.fs.path.sep_str ++ "draft.png") != null);
    try tst.expect(std.mem.indexOf(u8, path, "themes" ++ std.fs.path.sep_str ++ "policypress") == null);
}

test "draft mode: falls back to themes/policypress/static/draft.png when site-root copy absent" {
    const alloc = tst.allocator;
    var args = Array([]u8){};
    var conf = try config.load(alloc, TestConfig);
    defer conf.deinit(alloc);

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(tmp_path);
    try tmp.dir.makePath("themes/policypress/static");
    try tmp.dir.writeFile(.{ .sub_path = "themes/policypress/static/draft.png", .data = "" });

    alloc.free(conf.root);
    conf.root = try alloc.dupe(u8, tmp_path);
    conf.is_draft = true;
    try pandoc.create_global_args(alloc, &args, conf);
    defer pandoc.destroy_global_args(alloc, &args);

    const path = findPageBackground(args) orelse return error.NoBgArg;
    try tst.expect(std.mem.indexOf(u8, path, "themes" ++ std.fs.path.sep_str ++ "policypress" ++ std.fs.path.sep_str ++ "static" ++ std.fs.path.sep_str ++ "draft.png") != null);
}

test "draft mode: site-root static/draft.png wins over theme fallback when both exist" {
    const alloc = tst.allocator;
    var args = Array([]u8){};
    var conf = try config.load(alloc, TestConfig);
    defer conf.deinit(alloc);

    var tmp = tst.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(tmp_path);
    try tmp.dir.makePath("static");
    try tmp.dir.writeFile(.{ .sub_path = "static/draft.png", .data = "" });
    try tmp.dir.makePath("themes/policypress/static");
    try tmp.dir.writeFile(.{ .sub_path = "themes/policypress/static/draft.png", .data = "" });

    alloc.free(conf.root);
    conf.root = try alloc.dupe(u8, tmp_path);
    conf.is_draft = true;
    try pandoc.create_global_args(alloc, &args, conf);
    defer pandoc.destroy_global_args(alloc, &args);

    const path = findPageBackground(args) orelse return error.NoBgArg;
    try tst.expect(std.mem.indexOf(u8, path, "themes" ++ std.fs.path.sep_str ++ "policypress") == null);
}

// --- executableInPath ---

test "executableInPath: sh is present on unix" {
    if (comptime b.os.tag == .windows) return error.SkipZigTest;
    try tst.expect(pandoc.executableInPath("sh"));
}

test "executableInPath: nonexistent binary returns false" {
    try tst.expect(!pandoc.executableInPath("pp-test-nonexistent-xyzzy-12345"));
}

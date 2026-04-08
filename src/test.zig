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
    \\[extra]
    \\redact = true
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

    // try conf.validatePolicyFiles(alloc);

    // global_config.is_draft = true;
    // global_config.redact = true;

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

    tmp.cleanup();
}

test "report generation" {

    // var env = try std.process.getEnvMap(tst.allocator);
    // defer env.deinit();

    // var tmp = tst.tmpDir(.{});
    // const builddir = try tmp.dir.realpathAlloc(tst.allocator, ".");
    // defer tst.allocator.free(builddir);

    // const c_file = try std.fs.cwd().realpathAlloc(tst.allocator, "templates/opencontrols/standards/SCF.json");
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

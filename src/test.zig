const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const utils = @import("utils.zig");
const cr = @import("control_report.zig");
const fm = @import("frontmatter.zig");
const pandoc = @import("pandoc.zig");

// TODO
// - [ ] The reports should generate correctly
// - [ ] The test policy should render in html and pdf correctly
// - [ ] All configuration options in config.toml should be validated
// - [ ] All frontmatter options should be validated.

test {
    _ = utils;
    _ = cr;
    _ = fm;
    _ = pandoc;
    tst.refAllDeclsRecursive(@This());
}

test "policy processing" {
    const test_policy_file = try std.fs.cwd().openFile("content/policies/test_policy.md", .{});
    defer test_policy_file.close();
    const test_policy = try test_policy_file.readToEndAlloc(tst.allocator, std.math.maxInt(usize));
    defer tst.allocator.free(test_policy);

    var frontmatter = try fm.initFromMarkdown(tst.allocator, test_policy);
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

    var t1 = Array(u8).init(tst.allocator);
    defer t1.deinit();
    try t1.appendSlice(test_policy);
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

    try utils.replace_zola_at(&t1, "https://test.lol");
    try utils.replace_org(&t1, "loltest");
    try utils.replace_mermaid(&t1);
    try utils.redact(&t1, true);

    try tst.expect(std.mem.indexOf(u8, t1.items, "~~~mermaid") != null);
    try tst.expect(std.mem.indexOf(u8, t1.items, &[_]u8{0xDB} ** 10) != null);
    try tst.expectEqual(3, std.mem.count(u8, t1.items, "https://test.lol/"));
    try tst.expectEqual(0, std.mem.count(u8, t1.items, "{% end %}"));

    var args = Array([]u8).init(tst.allocator);
    var env = try std.process.getEnvMap(tst.allocator);
    defer env.deinit();

    const global_config = pandoc.Config{
        .root = env.get("DEVBOX_PROJECT_ROOT") orelse return error.NotRunningInDevboxEnv,
        .org = "testlol",
        .base_url = "https://test.lol",
        .current_year = 2025,
        .is_draft = true,
        .redact = true,
        .logo_path = "static/logo.png",
        .color = "#000fff",
        .build_dir = ".zig-cache",
        .work_file = "content/policies/test_policy.md",
    };

    try pandoc.create_global_args(tst.allocator, &args, global_config);
    defer pandoc.destroy_global_args(tst.allocator, args);
    const md = utils.MDFile{ .path = "content/policies/test_policy.md" };
    try pandoc.process_md_file(tst.allocator, md, args, global_config);

    // std.debug.print("{s}\n", .{t1.items});

    // try pandoc.process_md_file(tst.allocator, .{ .path = "content/policies/test_policy.md" });

    // std.debug.print("{}\n", .{frontmatter});
}

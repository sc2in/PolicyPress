const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const utils = @import("utils.zig");
const cr = @import("control_report.zig");
const fm = @import("frontmatter.zig");
const pandoc = @import("pandoc.zig");
const config = @import("config.zig").Config;

// TODO
// - [ ] The reports should generate correctly
// - [-] The test policy should render in html and pdf correctly
//   - [x] pdf
//   - [ ] html
// - [ ] All configuration options in config.toml should be validated
//      this requires the same logic that is holding up #45
// - [x] All frontmatter options should be validated.

test {
    _ = utils;
    _ = cr;
    _ = fm;
    _ = pandoc;
    tst.refAllDeclsRecursive(@This());
}

test "config loading and validation" {
    const alloc = tst.allocator;
    var conf = try config.load(alloc,
        \\base_url = "http://localhost:1111"
        \\[extra]
        \\redact = true
        \\policy_dir = "policies/"
        \\policy_root = "policies/_index.md"
        \\organization = "Star City Security Consulting"
        \\logo = "logo.png"
        \\pdf_color = "#0e90f3"
    );
    defer conf.deinit(alloc);
    errdefer conf.deinit(alloc);

    try conf.validatePolicyFiles(alloc);
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

    var args = Array([]u8){};
    var env = try std.process.getEnvMap(tst.allocator);
    defer env.deinit();

    var tmp = tst.tmpDir(.{});

    var global_config = try config.load_config_toml(tst.allocator);
    defer global_config.deinit(tst.allocator);

    // Free and replace root
    tst.allocator.free(global_config.root);
    global_config.root = try tst.allocator.dupe(u8, env.get("DEVBOX_PROJECT_ROOT") orelse
        return error.NotRunningInDevboxEnv);

    global_config.is_draft = true;
    global_config.redact = true;

    global_config.build_dir = try tmp.dir.realpathAlloc(tst.allocator, ".");

    try pandoc.create_global_args(tst.allocator, &args, global_config);
    defer pandoc.destroy_global_args(tst.allocator, &args);
    const md = utils.MDFile{ .path = "content/policies/test_policy.md" };
    pandoc.process_md_file(tst.allocator, md, args, global_config) catch |e| {
        std.debug.print("Test Policy Pandoc Call Failed! \nConfig:{any}\n", .{global_config});
        return e;
    };

    tmp.cleanup();
}

const b = @import("builtin");
test "report generation" {
    var env = try std.process.getEnvMap(tst.allocator);
    defer env.deinit();

    var tmp = tst.tmpDir(.{});
    const builddir = try tmp.dir.realpathAlloc(tst.allocator, ".");
    defer tst.allocator.free(builddir);

    const c_file = try std.fs.path.join(tst.allocator, &.{ env.get("DEVBOX_PROJECT_ROOT") orelse return error.NotRunningInDevboxEnv, "templates/opencontrols/standards/SCF.json" });
    defer tst.allocator.free(c_file);

    const c_path = try std.fs.path.join(tst.allocator, &.{env.get("DEVBOX_PROJECT_ROOT") orelse return error.NotRunningInDevboxEnv});
    const p_path = try std.fs.path.join(tst.allocator, &.{ env.get("DEVBOX_PROJECT_ROOT") orelse return error.NotRunningInDevboxEnv, "content/policies" });
    defer tst.allocator.free(c_path);
    defer tst.allocator.free(p_path);

    var f = try cr.init(tst.allocator, c_file);
    defer f.deinit();

    const rep = try f.report(p_path);
    var j = try std.json.parseFromSlice(std.json.Value, tst.allocator, rep, .{});
    defer j.deinit();
    try tst.expect(j.value.object.count() >= 1239); // test for number of controls read as of 10/2/2025
    try tst.expect(j.value.object.get("HRS-05").?.bool);
    try tst.expect(j.value.object.get("HRS-05.1").?.bool);
    try tst.expect(j.value.object.get("HRS-05.2").?.bool);
    try tst.expect(j.value.object.get("HRS-05.3").?.bool);
    try tst.expect(j.value.object.get("HRS-05.4").?.bool);
    try tst.expect(j.value.object.get("HRS-05.5").?.bool);
}

const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const tomlz = @import("tomlz");

var alloc: Allocator = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    alloc = gpa.allocator();

    var workDir = try std.fs.openDirAbsolute(
        std.posix.getenv("DEVBOX_PROJECT_ROOT") orelse return error.ProjectRootNotFoundInEnv,
        .{
            .access_sub_paths = true,
            .iterate = true,
        },
    );
    defer workDir.close();
    var conf_file = try workDir.openFile("config.toml", .{ .mode = .read_only });
    defer conf_file.close();

    const config_contents = try conf_file.readToEndAlloc(alloc, 100_000_000);
    defer alloc.free(config_contents);

    var config = try tomlz.parse(alloc, config_contents);
    defer config.deinit(alloc);

    const extra = config.getTable("extra") orelse return error.NoExtraInConfig;
    const policy_root = extra.getString("policy_root") orelse return error.NoPolicyRootInExtra;
    std.debug.print("{s}\n", .{policy_root});
    // const redact = b.option(bool, "redact", "Redact PDFs") orelse false;
    // const draft = b.option(bool, "redact", "Redact PDFs") orelse false;

    const md_files = try find_md_files(workDir, policy_root);
    for (md_files) |file| {
        std.debug.print("{s}\n", .{file});
    }
}

pub fn find_md_files(root: std.fs.Dir, policy_dir: []const u8) ![][]u8 {
    var files = Array([]u8).init(alloc);
    defer files.deinit();
    var policy_root = try (try root.openDir("content", .{
        .access_sub_paths = true,
        .iterate = true,
    })).openDir(policy_dir, .{
        .access_sub_paths = true,
        .iterate = true,
    });
    defer policy_root.close();

    try find_inner(&files, policy_root);
    return try files.toOwnedSlice();
}
fn find_inner(files: *Array([]u8), start: std.fs.Dir) !void {
    var iter = start.iterate();
    while (try iter.next()) |entry| {
        switch (entry.kind) {
            .file => {
                if (!std.mem.startsWith(u8, entry.name, "_") and
                    std.mem.endsWith(u8, entry.name, ".md"))
                    try files.append(try files.allocator.dupe(u8, entry.name));
            },
            .directory => {
                var sub = try start.openDir(entry.name, .{ .access_sub_paths = true, .iterate = true });
                defer sub.close();
                try find_inner(files, sub);
            },
            else => {},
        }
    }
}

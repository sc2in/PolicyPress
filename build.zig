const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;

pub fn build(b: *std.Build) !void {
    try pandoc_sh(b);
}

pub fn pandoc_sh(b: *std.Build) !void {
    var workDir = try std.fs.openDirAbsolute(
        std.posix.getenv("DEVBOX_PROJECT_ROOT") orelse return error.ProjectRootNotFoundInEnv,
        .{
            .access_sub_paths = true,
            .iterate = true,
        },
    );
    defer workDir.close();

    // const redact = b.option(bool, "redact", "Redact PDFs") orelse false;
    // const draft = b.option(bool, "redact", "Redact PDFs") orelse false;

    const md_files = try find_md_files(b, workDir);
    for (md_files) |file| {
        std.debug.print("{s}\n", .{file});
    }
}

pub fn find_md_files(b: *std.Build, root: std.fs.Dir) ![][]u8 {
    var files = Array([]u8).init(b.allocator);
    defer files.deinit();
    var policy_root = try root.openDir("content/policies", .{
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

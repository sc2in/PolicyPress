const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;

const Config = @import("pandoc.zig").Config;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stdout_writer = std.io.getStdOut().writer();

    const config = try Config.load_config_toml(allocator);
    defer config.deinit(allocator);

    // std.debug.print("{}\n", .{config});
    try std.json.stringify(config, .{ .whitespace = .indent_1 }, stdout_writer);
}

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

    var buffer: [128]u8 = undefined;
    var output_writer: std.fs.File.Writer = std.fs.File.stdout().writer(&buffer);
    const stdout: *std.Io.Writer = &output_writer.interface;

    const config = try Config.load_config_toml(allocator);
    defer config.deinit(allocator);

    // std.debug.print("{}\n", .{config});
    const output = try std.json.Stringify.valueAlloc(
        allocator,
        config,
        .{ .whitespace = .indent_1 },
    );
    defer allocator.free(output);

    try stdout.print("{s}\n", .{output});
    try stdout.flush();
}

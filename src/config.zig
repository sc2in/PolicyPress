const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const tomlz = @import("tomlz");

pub const BuildConfig = struct {
    base_url: []const u8,
    redact: []const u8,
    drafts: []const u8,

    const Self = @This();

    pub fn deinit(self: *Self, alloc: Allocator) void {
        alloc.free(self.base_url);
        alloc.free(self.redact);
        alloc.free(self.drafts);
    }
};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stdout_writer = std.io.getStdOut().writer();

    const config_path = if (args.len < 2) blk: {
        _ = std.fs.cwd().statFile("config.toml") catch {
            std.debug.print("Usage: config_parser <config.toml> (or run with config.toml in the cwd)\n", .{});

            return;
        };
        break :blk "config.toml";
    } else args[1];

    const file = try std.fs.cwd().openFile(config_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 1024);
    defer allocator.free(content);

    var config = try tomlz.parse(allocator, content);
    defer config.deinit(allocator);
    //BUG: This doesnt work in zig 0.14.1, but should in 0.14.0.
    // const b = try tomlz.decode(BuildConfig, allocator, content);

    const t = config.getString("base_url");
    try stdout_writer.print("--base-url={?s}\n", .{t});
    // var config = try tomlz.serialize( allocator, stdout_writer,content);
    // defer config.deinit(allocator);

    // // Output configuration as build options
    // std.debug.print("--Dbase_url={s} --Ddrafts={s} --Dredact={s}", .{
    //     config.base_url,
    //     config.drafts,
    //     config.redact,
    // });
}

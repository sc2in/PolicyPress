const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const tomlz = @import("tomlz");
const Datetime = @import("datetime");

/// Configuration read from config.toml
pub const BuildConfig = struct {
    base_url: []const u8,
    policy_dir: []const u8,
    root_dir: []const u8,
    year: []const u8,
    logo: []const u8,
    color: []const u8,
    organization: []const u8,
    // controls_file: []const u8 = "templates/opencontrols/standards/SCF.json",

    const Self = @This();

    pub fn deinit(self: Self, alloc: Allocator) void {
        inline for (std.meta.fields(Self)) |f| {
            alloc.free(@field(self, f.name));
        }
    }

    pub fn load_config_toml(alloc: Allocator) !BuildConfig {
        const file = try std.fs.cwd().openFile("config.toml", .{});
        defer file.close();

        const content = try file.readToEndAlloc(alloc, 1024 * 1024 * 1024);
        defer alloc.free(content);

        return try BuildConfig.load(alloc, content);
    }

    pub fn load(alloc: Allocator, content: []const u8) !BuildConfig {
        var t = try tomlz.parse(alloc, content);
        defer t.deinit(alloc);
        const e = t.getTable("extra") orelse return error.NoExtraInConfig;
        //BUG: This doesnt work in zig 0.14.1, but should in 0.14.0.
        // const b = try tomlz.decode(BuildConfig, allocator, content);
        var config: BuildConfig = undefined;
        const date = Datetime.datetime.Date.fromTimestamp(std.time.timestamp());

        config.root_dir = try std.fs.cwd().realpathAlloc(alloc, ".");
        config.year = try std.fmt.allocPrint(alloc, "{d}", .{date.year});

        config.base_url = try alloc.dupe(u8, t.getString("base_url") orelse return error.NoBaseUrlInConfig);
        config.policy_dir = try alloc.dupe(u8, e.getString("policy_dir") orelse return error.NoPolicyDirInExtra);
        config.logo = try alloc.dupe(u8, e.getString("logo") orelse return error.NoLogoInExtra);
        config.color = try alloc.dupe(u8, e.getString("pdf_color") orelse return error.NoPDFColorInExtra);
        config.organization = try alloc.dupe(u8, e.getString("organization") orelse return error.NoOrganizationInExtra);
        return config;
    }
};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stdout_writer = std.io.getStdOut().writer();

    const config = try BuildConfig.load_config_toml(allocator);
    defer config.deinit(allocator);

    // std.debug.print("{}\n", .{config});
    try std.json.stringify(config, .{ .whitespace = .indent_1 }, stdout_writer);
}

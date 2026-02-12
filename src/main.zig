const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const clap = @import("clap");
const Config = @import("config").Config;
const Reports = @import("reports");
const Pandoc = @import("pandoc");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-c, --config <str>     Path to config file. (default: config.toml)
        \\-i, --input  <str>     Path to input content directory. (default: content)
        \\-o, --output <str>     Path to output directory. (default: public)
        \\--no-draft             Do not add draft watermark to output.
        \\--no-redact            Do not redact text within redaction tags in output.
        \\-v, --verbose          Enable verbose logging.
    );
    var buf: [128]u8 = undefined;
    // Report useful error and exit.
    var stderr = std.fs.File.stderr().writer(&buf).interface;
    defer stderr.flush() catch {};
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(&stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("PolicyPress\n\n", .{});
        return clap.helpToFile(std.fs.File.stderr(), clap.Help, &params, .{});
    }
    const config_path = if (res.args.config) |c| c else "config.toml";
    const config_file = std.fs.cwd().openFile(config_path, .{}) catch |err| {
        std.debug.print("Error opening config file '{s}': {}\n", .{ config_path, err });
        return err;
    };
    const contents = try config_file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(contents);

    var config = try Config.load(alloc, contents);
    defer config.deinit(alloc);

    // if (res.args.verbose != 0) {
    //     .log_level = .debug;
    // }
    std.log.debug("Running PolicyPress with configuration:\n{f}\n", .{config});
}

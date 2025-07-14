const std = @import("std");
const zap = @import("zap");
const clap = @import("clap");

fn on_request(r: zap.Request) !void {
    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404 - File not found</h1></body></html>") catch return;
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-d, --dir <str>...     Directory to serve from. Defaults to `zig-out/public`
        \\
    );
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        // Report useful error and exit.
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("SC2 Policy Center Dev Server\nSee Readme.md or run `devbox build docs` to learn more.\n\n", .{});
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }
    const serve_dir = if (res.args.dir.len >= 1) res.args.dir[0] else "zig-out/public";
    zap.mimetypeRegister("wasm", "application/wasm");

    var listener = zap.HttpListener.init(.{
        .port = 1111,
        .on_request = on_request,
        .public_folder = serve_dir,
        .log = true,
    });
    try listener.listen();

    std.debug.print("Serving {s} on http://127.0.0.1:1111\n", .{serve_dir});

    // start worker threads
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}

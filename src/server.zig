//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
const std = @import("std");

const clap = @import("clap");
const zap = @import("zap");

fn on_request(r: zap.Request) !void {
    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404 - File not found</h1></body></html>") catch return;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    var ebuf: [256]u8 = undefined;
    var stderr = std.Io.File.stderr().writer(io, &ebuf).interface;

    // NB: keep every parameter single-valued (`<str>`, not `<str>...`). clap
    // 0.11.0's variadic path instantiates `std.ArrayListUnmanaged(T){}`, which
    // no longer compiles under Zig 0.16 (the empty literal must be `.empty`).
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                 Display this help and exit.
        \\-d, --dir <str>            Directory to serve from. Defaults to `public`.
        \\-i, --interface <str>      Interface to bind. Defaults to `127.0.0.1`; pass `0.0.0.0` for LAN access.
        \\
    );
    // clap needs an argument iterator. Convert the process args (skipping
    // argv[0], the binary name) to a slice and feed a SliceIterator, mirroring
    // src/main.zig — passing `init.minimal.args` straight to clap.parse no longer
    // compiles under the std.Io argv API.
    const argv = try init.minimal.args.toSlice(init.arena.allocator());
    const user_args: []const [:0]const u8 = if (argv.len > 1) argv[1..] else &.{};
    var arg_strs = try alloc.alloc([]const u8, user_args.len);
    defer alloc.free(arg_strs);
    for (user_args, 0..) |a, i| arg_strs[i] = a;
    var iter = clap.args.SliceIterator{ .args = arg_strs };

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &params, clap.parsers.default, &iter, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        // Report useful error and exit.
        diag.report(&stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("PolicyPress Dev Server\nSee Readme.md or run `nix run .#docs` to learn more.\n\n", .{});
        return clap.help(&stderr, clap.Help, &params, .{});
    }
    const serve_dir = res.args.dir orelse "public";

    // Bind loopback by default so drafts and internal policies aren't exposed
    // on the LAN during preview. zap's `interface` is a C string where null
    // means "all interfaces" (0.0.0.0); `--interface 0.0.0.0` opts into that.
    const host = if (res.args.interface) |i| i else "127.0.0.1";
    const host_z = try alloc.dupeZ(u8, host);
    defer alloc.free(host_z);

    zap.mimetypeRegister("wasm", "application/wasm");

    var listener = zap.HttpListener.init(.{
        .port = 1111,
        .interface = host_z.ptr,
        .on_request = on_request,
        .public_folder = serve_dir,
        .log = true,
    });
    try listener.listen();

    std.debug.print("Serving {s} on http://{s}:1111/\n", .{ serve_dir, host });

    // start worker threads
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}

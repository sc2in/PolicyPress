//! Regenerate a golden Typst-markup baseline. Renders one fixture and prints
//! the markup to stdout; build.zig wires one invocation per baseline behind the
//! `update-golden` step (which copies stdout into tests/golden/). Not meant to
//! be run by hand — use `zig build update-golden`.
//!
//! Usage: golden_gen <fixture.md> [--redact | --draft]

const std = @import("std");
const golden = @import("golden");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    const argv = try init.minimal.args.toSlice(init.arena.allocator());
    if (argv.len < 2) {
        std.debug.print("usage: golden_gen <fixture.md> [--redact|--draft]\n", .{});
        std.process.exit(2);
    }
    const fixture = argv[1];
    var mode: golden.Mode = .plain;
    if (argv.len >= 3) {
        if (std.mem.eql(u8, argv[2], "--redact")) {
            mode = .redact;
        } else if (std.mem.eql(u8, argv[2], "--draft")) {
            mode = .draft;
        }
    }

    const src = try golden.renderFixture(io, alloc, fixture, mode);
    defer alloc.free(src);

    var buf: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writer(io, &buf);
    try out.interface.writeAll(src);
    try out.interface.flush();
}

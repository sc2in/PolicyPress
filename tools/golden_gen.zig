//! Regenerate a golden Typst-markup baseline. Renders one fixture and prints
//! the markup to stdout; build.zig wires one invocation per baseline behind the
//! `update-golden` step (which copies stdout into tests/golden/). Not meant to
//! be run by hand — use `zig build update-golden`.
//!
//! Usage: golden_gen <fixture.md> [--redact | --draft]
//!        golden_gen --report <scf|soc2|review>

const std = @import("std");
const golden = @import("golden");
const reports = @import("reports");

pub const std_options: std.Options = .{
    // Debug builds default the std.log threshold to .debug, so tomlz's
    // .parser-scoped internals ("debug(parser): eatCommentsAndSpace", …)
    // land on stderr every time a baseline regenerates — and the zig 0.16
    // build runner re-prints any captured stderr from a passing step under
    // a misleading "failed command:" trailer (#197). Warnings and errors
    // stay audible; baselines go to stdout either way.
    .log_level = .warn,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    const argv = try init.minimal.args.toSlice(init.arena.allocator());
    if (argv.len < 2) {
        std.debug.print("usage: golden_gen <fixture.md> [--redact|--draft] | --report <scf|soc2|review>\n", .{});
        std.process.exit(2);
    }
    const fixture = argv[1];

    if (std.mem.eql(u8, fixture, "--controls")) {
        const src = try golden.renderControlFixture(io, alloc);
        defer alloc.free(src);
        var buf: [4096]u8 = undefined;
        var out = std.Io.File.stdout().writer(io, &buf);
        try out.interface.writeAll(src);
        try out.interface.flush();
        return;
    }

    if (std.mem.eql(u8, fixture, "--report")) {
        if (argv.len < 3) {
            std.debug.print("usage: golden_gen --report <scf|soc2|review>\n", .{});
            std.process.exit(2);
        }
        const kind = std.meta.stringToEnum(reports.Kind, argv[2]) orelse {
            std.debug.print("unknown report kind '{s}'\n", .{argv[2]});
            std.process.exit(2);
        };
        const src = try golden.renderReportFixture(io, alloc, kind);
        defer alloc.free(src);
        var buf: [4096]u8 = undefined;
        var out = std.Io.File.stdout().writer(io, &buf);
        try out.interface.writeAll(src);
        try out.interface.flush();
        return;
    }

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

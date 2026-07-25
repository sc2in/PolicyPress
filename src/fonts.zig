//! Copyright © 2026 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 OR PolyForm-Internal-Use-1.0.0
//!
//! Bundled Typst PDF fonts — Source Sans 3 (body) and Source Code Pro (mono).
//!
//! The four core weights/styles of each family are embedded into the binary
//! with `@embedFile`, so `typst compile` resolves the template's fonts without
//! a system font install or the nix `TYPST_FONT_PATHS`. At runtime they are
//! written once to a temp directory that is handed to typst via `--font-path`,
//! making PDF generation self-contained anywhere (bare checkout, container,
//! consumer repo — not just the devshell).
//!
//! Both families are licensed under the SIL Open Font License 1.1; see
//! `src/fonts/LICENSE.txt`. Only regular/italic/bold/bold-italic are shipped —
//! the preamble references no other weights, and typst's own embedded fonts
//! cover any incidental fallback.
const std = @import("std");
const Allocator = std.mem.Allocator;
const EnvMap = std.process.Environ.Map;

const log = std.log.scoped(.typst);

const Embedded = struct {
    name: []const u8,
    bytes: []const u8,
};

const embedded = [_]Embedded{
    .{ .name = "SourceSans3-Regular.otf", .bytes = @embedFile("fonts/SourceSans3-Regular.otf") },
    .{ .name = "SourceSans3-It.otf", .bytes = @embedFile("fonts/SourceSans3-It.otf") },
    .{ .name = "SourceSans3-Bold.otf", .bytes = @embedFile("fonts/SourceSans3-Bold.otf") },
    .{ .name = "SourceSans3-BoldIt.otf", .bytes = @embedFile("fonts/SourceSans3-BoldIt.otf") },
    .{ .name = "SourceCodePro-Regular.otf", .bytes = @embedFile("fonts/SourceCodePro-Regular.otf") },
    .{ .name = "SourceCodePro-It.otf", .bytes = @embedFile("fonts/SourceCodePro-It.otf") },
    .{ .name = "SourceCodePro-Bold.otf", .bytes = @embedFile("fonts/SourceCodePro-Bold.otf") },
    .{ .name = "SourceCodePro-BoldIt.otf", .bytes = @embedFile("fonts/SourceCodePro-BoldIt.otf") },
};

var mutex: std.Io.Mutex = .init;
var cached_path: ?[]const u8 = null;

/// Materialise the embedded fonts on disk and return an absolute directory to
/// pass to `typst --font-path`. Extraction happens once per process (guarded by
/// a mutex; the compile pipeline runs policies concurrently); later calls return
/// the cached path. The returned slice is owned by this module for the life of
/// the process — callers must not free it.
///
/// `gpa` is used only for transient allocations; the cached path is allocated
/// from the page allocator so its lifetime does not depend on the caller's
/// (possibly per-task/arena) allocator.
pub fn ensureFontPath(io: std.Io, gpa: Allocator, env: *EnvMap) ![]const u8 {
    mutex.lockUncancelable(io);
    defer mutex.unlock(io);

    if (cached_path) |p| return p;

    const tmpdir = env.get("TMPDIR") orelse env.get("TMP") orelse "/tmp";

    // A fresh, process-unique directory: two concurrent policypress processes
    // then never read a half-written font from one another, and there is no
    // stale-file cleanup to get wrong. Created once, reused for every policy
    // this run via `cached_path`.
    var suffix: u64 = undefined;
    io.random(std.mem.asBytes(&suffix));
    const dir_path = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "{s}/policypress-fonts-{x}",
        .{ tmpdir, suffix },
    );
    errdefer std.heap.page_allocator.free(dir_path);

    try std.Io.Dir.cwd().createDirPath(io, dir_path);

    for (embedded) |f| {
        const abs = try std.fs.path.join(gpa, &.{ dir_path, f.name });
        defer gpa.free(abs);
        var file = try std.Io.Dir.createFileAbsolute(io, abs, .{});
        defer file.close(io);
        try file.writeStreamingAll(io, f.bytes);
    }

    log.debug("extracted {d} bundled fonts to {s}\n", .{ embedded.len, dir_path });
    cached_path = dir_path;
    return dir_path;
}

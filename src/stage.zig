//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//!
//! `policypress stage-site` — the pre-Zola content-synthesis pass (#173).
//!
//! When `[extra.policypress] control_footnotes` is enabled, this stages a
//! disposable copy of the site root in which every content Markdown file gains
//! synthesised `[^CONTROL-ID]: …` footnote *definitions* — the web analogue of
//! what zigmark's `footnotes.resolve` does for the PDF. The web build then runs
//! `zola --root <stage> build`, so a bare `[^IAC-01]` resolves on the website
//! just as it already does in the PDF, and the `control()` shortcode becomes
//! optional rather than mandatory.
//!
//! Two invariants make this redaction-safe (the #116 property this must not
//! break):
//!
//!   * The transform is **append-only**. Authored bytes are copied verbatim and
//!     `[^ID]: …` definition lines are appended; nothing in the body — including
//!     `{% redact() %}` spans and `{{ control() }}` shortcodes — is rewritten, so
//!     the redaction chokepoint (`templates/shortcodes/redact.html`) still sees
//!     byte-identical input.
//!   * The synthesised definition text derives ONLY from catalog data (the SCF
//!     catalog + the policy library's taxonomy backlinks) via
//!     `ControlJoin.resolveFootnoteLinked` — never from document bodies — so no
//!     redacted content can flow into a definition.
//!
//! The staged copy lives outside the workspace (the caller passes an explicit
//! `-o`, e.g. `$RUNNER_TEMP/pp-stage`, in CI) and is never published. When the
//! flag is off, this prints `.` and stages nothing, so `zola --root . build`
//! degenerates to today's in-place build.

const std = @import("std");
const Allocator = std.mem.Allocator;
const tst = std.testing;

const Config = @import("config").Config;
const controls = @import("controls");
const zigmark = @import("zigmark");
const u = @import("utils");

const stagelog = std.log.scoped(.stage);

/// Upper bound for copying an individual site asset (image, font, etc.) into the
/// stage. Generous: static assets are the largest inputs and a static-site
/// bundle rarely holds a single file near this size.
const max_asset_bytes: usize = 256 << 20;

/// Top-level site directories copied verbatim into the stage, when present. This
/// mirrors what `zola build` reads from the site root besides `content/` (which
/// is processed) and `config.toml` (copied explicitly). `themes/` is included for
/// consumer sites that use PolicyPress as a theme; absent in this repo.
const copied_dirs = [_][]const u8{ "templates", "themes", "static", "sass", "data" };

const usage =
    \\Usage: policypress stage-site [OPTIONS]
    \\
    \\  Stage a site root for `zola build`. When [extra.policypress]
    \\  control_footnotes is enabled, each content Markdown file gets
    \\  synthesised [^CONTROL-ID]: footnote definitions appended in the
    \\  staged copy (the authored content/ is never modified). Otherwise
    \\  nothing is staged.
    \\
    \\  The site root path is printed to stdout — "." when the flag is off
    \\  (build in place), else the staging directory — so a caller can do:
    \\
    \\      zola --root "$(policypress stage-site -o "$TMP/stage")" build ...
    \\
    \\Options:
    \\  -c, --config <path>   Path to config.toml (default: config.toml)
    \\  -o, --output <dir>    Staging directory (default: .pp-stage)
    \\  -v, --verbose         Show debug output
    \\  -q, --quiet           Suppress progress output; errors only
    \\  -h, --help            Show this message
    \\
;

/// Entry point for the `stage-site` subcommand. On success prints exactly one
/// line to stdout — the site root for `zola build` — and logs progress to stderr.
///
/// `log_level` points at the process log level (owned by `main`); `-v`/`-q`
/// adjust it. Passed by pointer rather than importing `main` so this file's
/// dependency set stays small enough to compile into the unit-test module.
pub fn run(io: std.Io, gpa: Allocator, args: []const [:0]const u8, log_level: *std.log.Level) !void {
    var config_path: []const u8 = "config.toml";
    var output_dir: []const u8 = ".pp-stage";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.debug.print("{s}", .{usage});
            return;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            log_level.* = .debug;
        } else if (std.mem.eql(u8, arg, "-q") or std.mem.eql(u8, arg, "--quiet")) {
            log_level.* = .err;
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--config")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("policypress stage-site: {s} requires a value\n\n{s}", .{ arg, usage });
                std.process.exit(1);
            }
            config_path = args[i];
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("policypress stage-site: {s} requires a value\n\n{s}", .{ arg, usage });
                std.process.exit(1);
            }
            output_dir = args[i];
        } else {
            std.debug.print("policypress stage-site: unexpected argument '{s}'\n\n{s}", .{ arg, usage });
            std.process.exit(1);
        }
    }

    // One-shot CLI: an arena keeps the config, control-join, and per-file buffers
    // simple to manage — everything is freed at process exit.
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const contents = std.Io.Dir.cwd().readFileAlloc(io, config_path, arena, .limited(u.max_config_bytes)) catch |err| {
        std.debug.print("policypress stage-site: cannot read config '{s}': {s}\n", .{ config_path, @errorName(err) });
        std.process.exit(1);
    };
    var config = Config.load(io, arena, contents) catch |err| {
        std.debug.print("policypress stage-site: invalid config '{s}': {s}\n", .{ config_path, @errorName(err) });
        std.process.exit(1);
    };

    // Flag off → nothing to stage. Print "." so the caller builds in place.
    if (!config.control_footnotes) {
        stagelog.info("control_footnotes disabled; building in place (no staging)", .{});
        try printLine(io, ".");
        return;
    }

    try stageSite(io, arena, config_path, output_dir, &config);

    // The only stdout line: the staged site root for `zola --root`.
    try printLine(io, output_dir);
}

/// Materialise the staged site root: wipe/recreate `output_dir`, copy the config
/// and the verbatim site directories, then walk `content/` appending synthesised
/// control-footnote definitions to each Markdown file.
fn stageSite(io: std.Io, arena: Allocator, config_path: []const u8, output_dir: []const u8, config: *Config) !void {
    const cwd = std.Io.Dir.cwd();

    // Build the control-ID join exactly as the PDF build does, so the web
    // definitions come from the same code path: SCF catalog + optional praxis
    // join + a library of the non-draft policies (drives "See also").
    const policy_paths = try collectNonDraftPolicies(io, arena, config.policy_dir);
    stagelog.debug("staging with {d} non-draft policies in the control library", .{policy_paths.len});

    const scf_catalog_path = try std.fs.path.join(arena, &.{ config.root, "data/scf.json" });
    const scf_exists = if (cwd.access(io, scf_catalog_path, .{})) |_| true else |_| false;
    const tsc_catalog_path = try std.fs.path.join(arena, &.{ config.root, "data/tsc2017.json" });
    const tsc_exists = if (cwd.access(io, tsc_catalog_path, .{})) |_| true else |_| false;
    const join_path: ?[]const u8 = if (config.praxis_join) |rel|
        try std.fs.path.join(arena, &.{ config.root, rel })
    else
        null;

    var control_join = try controls.ControlJoin.init(
        io,
        arena,
        if (scf_exists) scf_catalog_path else null,
        if (tsc_exists) tsc_catalog_path else null,
        join_path,
        policy_paths,
    );
    // Arena-backed; no deinit needed.

    // The web link target for a control id: the already-resolved site path of the
    // SCF report page (e.g. `/reports/scf/`), so the definition's id links to the
    // control's row — paralleling the control() shortcode's inline link. A plain
    // absolute path (not an `@/…` link) deliberately sidesteps Zola's internal
    // link/anchor validation. Unset → plain-text ids (matches control.html's
    // <span> fallback).
    const link_base: ?[]const u8 = blk: {
        const page = scfReportPage(config) orelse break :blk null;
        break :blk try u.zolaAtToSitePath(arena, page);
    };
    if (link_base) |lb| stagelog.debug("linking control footnotes to {s}#<id>", .{lb});

    // Wipe and recreate the staging directory.
    cwd.deleteTree(io, output_dir) catch {};
    try cwd.createDirPath(io, output_dir);

    // Copy config.toml (as the staged root's config.toml, whatever the source
    // name) and each verbatim site directory that exists.
    const staged_config = try std.fs.path.join(arena, &.{ output_dir, "config.toml" });
    try cwd.copyFile(config_path, cwd, staged_config, io, .{ .make_path = true, .replace = true });
    for (copied_dirs) |dir| {
        if (cwd.access(io, dir, .{})) |_| {
            try copyDirTree(io, arena, dir, output_dir);
        } else |_| {
            stagelog.debug("site directory '{s}' absent; skipping", .{dir});
        }
    }

    // Process content/: verbatim for non-Markdown, append-synthesise for .md.
    try stageContent(io, arena, output_dir, config, &control_join, link_base);
    stagelog.info("staged site root at '{s}'", .{output_dir});
}

/// Copy every file under `src` (recursively) into `<out>/<src>/…`, preserving the
/// relative layout. Uses `copyFile` with `make_path` so parent directories are
/// created on demand (empty directories are not reproduced — Zola needs none).
fn copyDirTree(io: std.Io, arena: Allocator, src: []const u8, out: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    var dir = try cwd.openDir(io, src, .{ .iterate = true, .access_sub_paths = true });
    defer dir.close(io);

    var walker = try dir.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const src_path = try std.fs.path.join(arena, &.{ src, entry.path });
        const dst_path = try std.fs.path.join(arena, &.{ out, src, entry.path });
        try cwd.copyFile(src_path, cwd, dst_path, io, .{ .make_path = true, .replace = true });
    }
}

/// Walk `content/` and materialise it under `<out>/content/`. Non-Markdown files
/// are copied verbatim; each `.md` file is copied with synthesised
/// `[^CONTROL-ID]: …` definitions appended (append-only — the authored bytes are
/// untouched).
fn stageContent(
    io: std.Io,
    arena: Allocator,
    out: []const u8,
    config: *Config,
    control_join: *const controls.ControlJoin,
    link_base: ?[]const u8,
) !void {
    const cwd = std.Io.Dir.cwd();
    var dir = try cwd.openDir(io, "content", .{ .iterate = true, .access_sub_paths = true });
    defer dir.close(io);

    var walker = try dir.walk(arena);
    defer walker.deinit();

    var files: usize = 0;
    var defs_total: usize = 0;
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const src_path = try std.fs.path.join(arena, &.{ "content", entry.path });
        const dst_path = try std.fs.path.join(arena, &.{ out, "content", entry.path });

        if (!std.mem.endsWith(u8, entry.basename, ".md")) {
            try cwd.copyFile(src_path, cwd, dst_path, io, .{ .make_path = true, .replace = true });
            continue;
        }

        files += 1;
        // self_path for "See also" exclusion: the same absolute key the control
        // library is built from, so a policy's own footnotes never list it. For
        // non-policy content (guides) this matches no library entry, so every
        // covering policy is listed — the correct document-agnostic behaviour.
        const self_path = try std.fs.path.join(arena, &.{ config.content_dir, entry.path });
        defs_total += try stageMarkdownFile(io, arena, src_path, dst_path, control_join, self_path, link_base);
    }
    stagelog.info("processed {d} content Markdown file(s); appended {d} control-footnote definition(s)", .{ files, defs_total });
}

/// Copy one Markdown file, appending a synthesised definition for every dangling
/// control-shaped footnote reference it contains. Returns the number of
/// definitions appended. Append-only: the source bytes are emitted unchanged and
/// the definitions follow, so redaction spans and shortcodes are byte-identical.
pub fn stageMarkdownFile(
    io: std.Io,
    arena: Allocator,
    src_path: []const u8,
    dst_path: []const u8,
    control_join: *const controls.ControlJoin,
    self_path: []const u8,
    link_base: ?[]const u8,
) !usize {
    const cwd = std.Io.Dir.cwd();
    const src = try cwd.readFileAlloc(io, src_path, arena, .limited(u.max_policy_bytes));

    // Find dangling footnote references (author-typed `[^…]` with no definition).
    // Shortcodes are still `{{ … }}` text at this stage, so only genuine native
    // references are seen. AST-based, so refs inside code fences do not count.
    var parser = zigmark.Parser.init();
    defer parser.deinit(arena);
    var appended = std.Io.Writer.Allocating.init(arena);
    var count: usize = 0;
    if (parser.parseMarkdown(arena, src)) |doc_val| {
        var doc = doc_val;
        defer doc.deinit(arena);
        if (zigmark.footnotes.dangling(arena, &doc)) |dangs| {
            defer {
                for (dangs) |d| arena.free(d);
                arena.free(dangs);
            }
            for (dangs) |label| {
                if (!controls.isControlId(label)) continue;
                // Only a known id gets a synthesised web definition. An unknown
                // well-formed id is left dangling here (it renders as literal
                // text); the --strict preflight is what flags it as a typo.
                if (control_join.catalog) |*cat| {
                    if (!cat.map.contains(label)) {
                        stagelog.warn("{s}: unknown control id '{s}' in footnote reference; not synthesising a definition", .{ src_path, label });
                        continue;
                    }
                }
                const body = (try control_join.resolveFootnoteLinked(arena, label, self_path, link_base)) orelse continue;
                try appended.writer.print("\n[^{s}]: {s}\n", .{ label, body });
                count += 1;
            }
        } else |err| {
            stagelog.debug("{s}: could not scan footnotes ({s}); copied verbatim", .{ src_path, @errorName(err) });
        }
    } else |err| {
        stagelog.debug("{s}: unparseable for footnote synthesis ({s}); copied verbatim", .{ src_path, @errorName(err) });
    }

    // Ensure the parent directory exists, then write source + appended defs.
    if (std.fs.path.dirname(dst_path)) |parent| try cwd.createDirPath(io, parent);
    if (count == 0) {
        try cwd.writeFile(io, .{ .sub_path = dst_path, .data = src });
        return 0;
    }
    // A blank line before the appended block guarantees the definitions start a
    // new block even when the source has no trailing newline.
    var out_file = try cwd.createFile(io, dst_path, .{ .truncate = true });
    defer out_file.close(io);
    try out_file.writeStreamingAll(io, src);
    if (!std.mem.endsWith(u8, src, "\n")) try out_file.writeStreamingAll(io, "\n");
    try out_file.writeStreamingAll(io, appended.written());
    return count;
}

/// Collect the absolute paths of the non-draft policy Markdown files under
/// `policy_dir`, mirroring the discovery in `runBuild` (skips `_index.md` and
/// `draft: true` policies) so the staged control library matches the build's.
fn collectNonDraftPolicies(io: std.Io, arena: Allocator, policy_dir: []const u8) ![]const []const u8 {
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, policy_dir, .{ .iterate = true, .access_sub_paths = true }) catch |err| {
        stagelog.warn("cannot open policy directory '{s}' ({s}); control library will be empty", .{ policy_dir, @errorName(err) });
        return &.{};
    };
    defer dir.close(io);

    var walker = try dir.walk(arena);
    defer walker.deinit();

    var list = std.ArrayList([]const u8).empty;
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".md")) continue;
        if (std.mem.eql(u8, entry.basename, "_index.md")) continue;
        if (u.isDraftPolicy(io, arena, dir, entry.path)) continue;
        const abs = try std.fs.path.join(arena, &.{ policy_dir, entry.path });
        try list.append(arena, abs);
    }
    return list.items;
}

/// `[extra.policypress] scf_report_page`, or null when unset. Borrowed from the
/// config's toml table.
fn scfReportPage(config: *Config) ?[]const u8 {
    const t = config.zola_config orelse return null;
    const extra = t.getTable("extra") orelse return null;
    const pp = extra.getTable("policypress") orelse return null;
    return pp.getString("scf_report_page");
}

/// Write one line to stdout (the subcommand's sole stdout output).
fn printLine(io: std.Io, line: []const u8) !void {
    var buf: [std.fs.max_path_bytes + 2]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    try w.interface.print("{s}\n", .{line});
    try w.interface.flush();
}

// ── Tests ─────────────────────────────────────────────────────────────────────
// stageMarkdownFile's file-system behaviour is exercised end-to-end by
// tests/redaction-leak-check.sh (append-only + no-leak). The append-only shape
// of the synthesised block is a property worth pinning here too, but it needs a
// ControlJoin fixture, which lives with the other control tests in src/test.zig.
test {
    tst.refAllDecls(@This());
}

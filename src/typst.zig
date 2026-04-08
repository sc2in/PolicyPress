//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//!
//! Typst-based PDF compiler — drop-in replacement for the Pandoc pipeline.
//!
//! Pipeline:
//!   Markdown → shortcode pre-processing → zigmark AST → Typst markup → typst compile → PDF
//!
//! Advantages over pandoc + xelatex:
//!   - No xelatex / fontconfig dependency (single `typst` binary)
//!   - Significantly faster render time
//!   - Markdown parsing handled in-process by zigmark
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const zigmark = @import("zigmark");
const u = @import("utils");
const Config = @import("config").Config;

const log = std.log.scoped(.typst);

/// Compile a single Markdown policy file to PDF via the Typst engine.
/// Drop-in replacement for `pandoc.compile/3`.
pub fn compile(
    alloc: Allocator,
    config: Config,
    input_file: []const u8,
) !void {
    log.debug("typst: processing {s}\n", .{input_file});

    // ── 1. Read source ────────────────────────────────────────────────────────

    var dir = try std.fs.cwd().openDir(config.root, .{});
    defer dir.close();

    var file = dir.openFile(input_file, .{ .mode = .read_only }) catch |e| {
        if (e == error.FileNotFound)
            log.err("file not found: {s}/{s}\n", .{ config.root, input_file });
        return e;
    };
    defer file.close();

    const raw = try file.readToEndAlloc(alloc, 100_000_000);
    var contents = Array(u8){ .items = raw, .capacity = raw.len };
    defer contents.deinit(alloc);

    // ── 2. Pre-process shortcodes (same as pandoc pipeline) ───────────────────

    try u.replace_org(alloc, &contents, config.org);
    try u.replace_zola_at(alloc, &contents, config.base_url);
    try u.replace_admonitions(alloc, &contents);
    try u.replace_mermaid(alloc, &contents);
    try u.redact(alloc, &contents, config.redact);

    // ── 3. Extract frontmatter for filename generation ────────────────────────

    var fm = try u.get_metadata(alloc, &contents, config);
    defer fm.deinit(alloc);

    // ── 4. Parse Markdown → AST ───────────────────────────────────────────────

    var parser = zigmark.Parser.init();
    var doc = try parser.parseMarkdown(alloc, contents.items);
    defer doc.deinit(alloc);

    // ── 5. Build DocumentOptions from config ──────────────────────────────────

    const color = if (config.color[0] == '#') config.color[1..] else config.color;

    const footer_left = try std.fmt.allocPrint(
        alloc,
        "{s} \u{00a9} {d}",
        .{ config.org, config.current_year },
    );
    defer alloc.free(footer_left);

    const title = try buildTitle(alloc, fm.title, config);
    defer alloc.free(title);

    const opts = zigmark.typst.DocumentOptions{
        .title                = title,
        .author               = config.org,
        .paper                = "us-letter",
        .titlepage            = true,
        .titlepage_color      = color,
        .titlepage_rule_color = color,
        .toc                  = true,
        .toc_depth            = 3,
        .footer_left          = footer_left,
        .footer_center        = "Confidential",
        .colorlinks           = true,
    };

    // ── 6. Render Typst markup ────────────────────────────────────────────────

    const body = try zigmark.typst.renderDocument(alloc, doc, opts);
    defer alloc.free(body);

    // Draft watermark: prepend a #set page(background: ...) before the preamble.
    // Typst merges #set rules for different fields, so this coexists cleanly
    // with the preamble's header/footer/paper setup.
    const typ_src = if (config.is_draft) blk: {
        const src = try std.fmt.allocPrint(alloc,
            \\#set page(background: place(center + horizon,
            \\  rotate(-45deg,
            \\    text(120pt, fill: rgb("#00000015"), weight: "bold")[DRAFT]
            \\  )
            \\))
            \\{s}
        , .{body});
        break :blk src;
    } else try alloc.dupe(u8, body);
    defer alloc.free(typ_src);

    // ── 7. Write .typ alongside the PDF output ────────────────────────────────
    // typst requires the source file to be within --root, so we can't use /tmp.
    // Write it into the build dir and clean it up after compilation.

    var env = try std.process.getEnvMap(alloc);
    defer env.deinit();

    const pid = std.os.linux.getpid();
    const typ_name = try std.fmt.allocPrint(
        alloc,
        ".pp_{d}_{s}.typ",
        .{ pid, std.fs.path.basename(input_file) },
    );
    defer alloc.free(typ_name);
    // Must be within --root so typst's "source file must be contained in project
    // root" constraint is satisfied regardless of where -o points.
    const typ_abs = try std.fs.path.join(alloc, &.{ config.root, typ_name });
    defer alloc.free(typ_abs);

    const typ_file = std.fs.createFileAbsolute(typ_abs, .{ .exclusive = true }) catch |e| blk: {
        if (e == error.PathAlreadyExists) {
            std.fs.deleteFileAbsolute(typ_abs) catch {};
            break :blk try std.fs.createFileAbsolute(typ_abs, .{});
        }
        return e;
    };
    defer {
        typ_file.close();
        std.fs.deleteFileAbsolute(typ_abs) catch {};
    }
    try typ_file.writeAll(typ_src);

    // ── 8. Sanitise output filename ───────────────────────────────────────────

    const out = try fm.filename(alloc);
    defer alloc.free(out);
    std.mem.replaceScalar(u8, out, ' ', '_');
    sanitizeFilename(out);

    const out_path = try std.fmt.allocPrint(
        alloc,
        "{s}/{s}",
        .{ config.build_dir, out },
    );
    defer alloc.free(out_path);

    // ── 9. Run typst compile ──────────────────────────────────────────────────

    try runTypst(alloc, typ_abs, out_path, config.root, &env);
}

/// Append "(Draft)" / "(Redacted)" suffixes matching the pandoc pipeline.
fn buildTitle(alloc: Allocator, base: []const u8, config: Config) ![]u8 {
    if (config.is_draft and config.redact)
        return std.fmt.allocPrint(alloc, "{s} (Redacted) (Draft)", .{base});
    if (config.is_draft)
        return std.fmt.allocPrint(alloc, "{s} (Draft)", .{base});
    if (config.redact)
        return std.fmt.allocPrint(alloc, "{s} (Redacted)", .{base});
    return alloc.dupe(u8, base);
}

/// Sanitise an output filename in-place (path traversal + unsafe char prevention).
fn sanitizeFilename(name: []u8) void {
    var prev_dot = false;
    for (name, 0..) |*ch, i| {
        var c = ch.*;
        if (c == '/' or c == '\\') c = '_';
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-' and c != '.') c = '_';
        if (c == '.') {
            if (i == 0 or prev_dot) { c = '_'; prev_dot = false; }
            else prev_dot = true;
        } else prev_dot = false;
        ch.* = c;
    }
}

/// Spawn `typst compile --root <root> <input.typ> <output.pdf>` and wait.
fn runTypst(
    alloc: Allocator,
    input: []const u8,
    output: []const u8,
    root: []const u8,
    env: *std.process.EnvMap,
) !void {
    const root_abs = try std.fs.cwd().realpathAlloc(alloc, root);
    defer alloc.free(root_abs);

    const argv = [_][]const u8{ "typst", "compile", "--root", root_abs, input, output };
    log.debug("running: typst compile --root {s} {s} {s}\n", .{ root_abs, input, output });

    var child = std.process.Child.init(&argv, alloc);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.env_map = env;

    var out_buf: std.ArrayListUnmanaged(u8) = .empty;
    var err_buf: std.ArrayListUnmanaged(u8) = .empty;
    defer {
        out_buf.deinit(alloc);
        err_buf.deinit(alloc);
    }

    child.spawn() catch |e| {
        if (e == error.FileNotFound) {
            std.debug.print(
                "policypress: typst not found in PATH.\n" ++
                    "Make sure typst is in your devshell (add it to flake.nix).\n",
                .{},
            );
            return error.TypstNotFound;
        }
        return e;
    };

    try child.collectOutput(alloc, &out_buf, &err_buf, 10 * 1024 * 1024);
    const term = try child.wait();

    if (term != .Exited or term.Exited != 0) {
        log.err("typst failed for {s}:\n{s}\n", .{ input, err_buf.items });
        return error.TypstFailed;
    }

    log.info("compiled: {s}\n", .{output});
}

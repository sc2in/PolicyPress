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
//!
//! The generated PDF matches the eisvogel/policypress pandoc output:
//!   - Title page: logo (bottom-left), title, version, org, last-reviewed, coloured rule
//!   - Header: document title (left) + logo (right)
//!   - Footer: "Org © Year" | "Confidential" | page number
//!   - Table of contents
//!   - Body
//!   - Version History table (from extra.major_revisions frontmatter)
//!   - Draft watermark (diagonal "DRAFT" on every page when --draft)
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const zigmark = @import("zigmark");
const u = @import("utils");
const Config = @import("config").Config;

const log = std.log.scoped(.typst);

/// Options for the policypress-specific Typst preamble.
const DocOpts = struct {
    /// Full title shown on the title page (may include "(Redacted)"/"(Draft)" suffixes).
    title: []const u8,
    /// Raw policy title used in the running page header (no suffixes).
    header_title: []const u8,
    author: []const u8,
    /// Six-digit hex colour (no `#` prefix) for the title-page rule.
    color: []const u8,
    /// Logo path relative to the `.typ` source file, or null to omit logo.
    logo_rel: ?[]const u8,
    footer_left: []const u8,
    footer_center: []const u8,
    version: []const u8,
    last_reviewed: []const u8,
    is_draft: bool,
};

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
    // `u.redact` fills redacted blocks with `_` characters, which CommonMark
    // parses as thematic breaks (→ thin gray lines in Typst).  Replace them
    // with `█` (U+2588 FULL BLOCK) so they render as solid black bars.
    if (config.redact) try underscoresToBlocks(alloc, &contents);

    // ── 3. Extract frontmatter ────────────────────────────────────────────────

    var fm = try u.get_metadata(alloc, &contents, config);
    defer fm.deinit(alloc);

    // Parse frontmatter a second time with the zigmark API to get the full
    // major_revisions array (u.get_metadata only returns the most recent version).
    var raw_fm = try zigmark.Frontmatter.initFromMarkdown(alloc, contents.items);
    defer raw_fm.deinit();

    // ── 4. Parse Markdown → AST ───────────────────────────────────────────────

    var parser = zigmark.Parser.init();
    var doc = try parser.parseMarkdown(alloc, contents.items);
    defer doc.deinit(alloc);

    // ── 5. Build Typst source ─────────────────────────────────────────────────

    const color = if (config.color[0] == '#') config.color[1..] else config.color;

    const footer_left = try std.fmt.allocPrint(
        alloc,
        "{s} \u{00a9} {d}",
        .{ config.org, config.current_year },
    );
    defer alloc.free(footer_left);

    // The PDF displays the clean policy title (no "(Redacted)"/"(Draft)" suffixes).
    // fm.title (with suffixes) is only used for the output filename.
    const raw_title: []const u8 = blk: {
        if (raw_fm.get("title")) |v| {
            if (v == .string) break :blk v.string;
        }
        break :blk fm.title;
    };

    // Running header: "Policy Name v1.1" for at-a-glance identification.
    const header_title = try std.fmt.allocPrint(alloc, "{s} v{s}", .{ raw_title, fm.most_recent_version });
    defer alloc.free(header_title);

    // Compute the logo path relative to the .typ file (which is written into
    // config.root).  config.logo_path == "{root}/static/logo.png", so the
    // relative path is "static/logo.png".  Skip the logo if the file is absent.
    const logo_rel: ?[]const u8 = blk: {
        if (!std.mem.startsWith(u8, config.logo_path, config.root)) break :blk null;
        std.fs.accessAbsolute(config.logo_path, .{}) catch break :blk null;
        break :blk config.logo_path[config.root.len + 1 ..];
    };

    // Render the Markdown body to Typst markup (body only, no preamble).
    const body = try zigmark.typst.render(alloc, doc);
    defer alloc.free(body);

    // Assemble the complete Typst source.
    var aw: std.Io.Writer.Allocating = .init(alloc);
    defer aw.deinit();

    try writePreamble(&aw.writer, .{
        .title        = raw_title,
        .header_title = header_title,
        .author       = config.org,
        .color        = color,
        .logo_rel     = logo_rel,
        .footer_left  = footer_left,
        .footer_center = "Confidential",
        .version      = fm.most_recent_version,
        .last_reviewed = fm.last_reviewed,
        .is_draft     = config.is_draft,
    });
    try aw.writer.writeAll(body);
    try writeVersionHistory(&aw.writer, &raw_fm);

    const typ_src = try aw.toOwnedSlice();
    defer alloc.free(typ_src);

    // ── 6. Write .typ alongside the PDF output ────────────────────────────────
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

    // ── 7. Sanitise output filename ───────────────────────────────────────────

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

    // ── 8. Run typst compile ──────────────────────────────────────────────────

    try runTypst(alloc, typ_abs, out_path, config.root, &env);
}

// ── Typst escape helpers ──────────────────────────────────────────────────────

/// Write `s` with Typst markup-mode special characters escaped.
fn writeEscaped(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '\\' => try writer.writeAll("\\\\"),
            '*'  => try writer.writeAll("\\*"),
            '_'  => try writer.writeAll("\\_"),
            '`'  => try writer.writeAll("\\`"),
            '#'  => try writer.writeAll("\\#"),
            '$'  => try writer.writeAll("\\$"),
            '@'  => try writer.writeAll("\\@"),
            '<'  => try writer.writeAll("\\<"),
            '['  => try writer.writeAll("\\["),
            ']'  => try writer.writeAll("\\]"),
            '~'  => try writer.writeAll("\\~"),
            else => try writer.writeByte(c),
        }
    }
}

/// Write `s` inside a Typst string literal (double-quoted). Only `"` and `\`
/// need escaping in this context.
fn writeStringLit(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"'  => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            else => try writer.writeByte(c),
        }
    }
}

// ── Redaction bar helper ──────────────────────────────────────────────────────

/// Replace `_` characters in the **body** of `txt` (after the frontmatter) with
/// the UTF-8 solid-block character `█` (U+2588).
///
/// `u.redact` fills redacted spans with underscores.  In CommonMark, a run of
/// three or more `_` on its own line is a thematic break, so zigmark renders it
/// as `#line(...)` — a thin gray rule.  Replacing with `█` produces proper
/// black-bar redaction marks without any special Markdown meaning.
///
/// Only the body is processed; the frontmatter block (keys like `last_reviewed`,
/// `major_revisions`) must remain intact for the later metadata extraction pass.
fn underscoresToBlocks(alloc: Allocator, txt: *Array(u8)) !void {
    const block = "█"; // 3-byte UTF-8: 0xE2 0x96 0x88
    if (std.mem.indexOfScalar(u8, txt.items, '_') == null) return;

    // Locate the end of the frontmatter so we leave it untouched.
    const content = txt.items;
    const body_start: usize = blk: {
        if (content.len < 4) break :blk 0;
        const delim: []const u8 = switch (content[0]) {
            '-' => "---",
            '+' => "+++",
            else => break :blk 0,
        };
        const close = std.mem.indexOfPos(u8, content, 3, delim) orelse break :blk 0;
        break :blk close + delim.len;
    };

    var aw: std.Io.Writer.Allocating = .init(alloc);
    defer aw.deinit();
    // Copy the frontmatter verbatim.
    try aw.writer.writeAll(content[0..body_start]);
    // Replace underscores in the body with █.
    // Insert a space every 10 blocks so Typst can wrap the bar within the text
    // width (u.redact replaces spaces too, producing one unbreakable "word").
    var block_count: usize = 0;
    for (content[body_start..]) |c| {
        if (c == '_') {
            try aw.writer.writeAll(block);
            block_count += 1;
            if (block_count % 10 == 0) try aw.writer.writeByte(' ');
        } else {
            block_count = 0;
            try aw.writer.writeByte(c);
        }
    }
    const new_bytes = try aw.toOwnedSlice();
    txt.deinit(alloc);
    txt.* = Array(u8){ .items = new_bytes, .capacity = new_bytes.len };
}

// ── Preamble ──────────────────────────────────────────────────────────────────

fn writePreamble(writer: anytype, opts: DocOpts) !void {
    // ── Document metadata ─────────────────────────────────────────────────────
    try writer.writeAll("#set document(\n  title: \"");
    try writeStringLit(writer, opts.title);
    try writer.writeAll("\",\n  author: \"");
    try writeStringLit(writer, opts.author);
    try writer.writeAll("\",\n)\n\n");

    // ── Draft watermark helper (reused on both the body pages and title page) ─
    // Defined as a let-binding so it can be referenced in both #set page and
    // the explicit #page(...) call for the title page.
    if (opts.is_draft) {
        try writer.writeAll(
            "#let _pp_draft_bg = place(center + horizon,\n" ++
            "  rotate(-45deg,\n" ++
            "    text(120pt, fill: rgb(\"#00000015\"), weight: \"bold\")[DRAFT]\n" ++
            "  )\n" ++
            ")\n\n",
        );
    }

    // ── Page layout (body pages) ──────────────────────────────────────────────
    try writer.writeAll("#set page(\n  paper: \"us-letter\",\n  margin: (x: 2.5cm, y: 2.5cm),\n");

    if (opts.is_draft) {
        try writer.writeAll("  background: _pp_draft_bg,\n");
    }

    // Header: title (left) | empty (center) | logo (right)
    try writer.writeAll(
        "  header: [\n" ++
        "    #set text(size: 9pt, fill: rgb(\"#777777\"))\n" ++
        "    #grid(\n" ++
        "      columns: (1fr, 1fr, 1fr),\n" ++
        "      align: (left, center, right),\n" ++
        "      [",
    );
    try writeEscaped(writer, opts.header_title);
    try writer.writeAll("],\n      [],\n      [");
    if (opts.logo_rel) |logo| {
        // height: 20pt keeps the logo within the header line without clipping.
        try writer.writeAll("#image(\"");
        try writeStringLit(writer, logo);
        try writer.writeAll("\", height: 20pt)");
    }
    try writer.writeAll("],\n    )\n  ],\n");

    // Footer: "Org © Year" (left) | "Confidential" (center) | page number (right)
    try writer.writeAll(
        "  footer: [\n" ++
        "    #set text(size: 9pt, fill: rgb(\"#777777\"))\n" ++
        "    #grid(\n" ++
        "      columns: (1fr, 1fr, 1fr),\n" ++
        "      align: (left, center, right),\n" ++
        "      [",
    );
    try writeEscaped(writer, opts.footer_left);
    try writer.writeAll("],\n      [");
    try writeEscaped(writer, opts.footer_center);
    try writer.writeAll("],\n      [#context counter(page).display(\"1\")],\n    )\n  ],\n)\n\n");

    // ── Text / font settings ──────────────────────────────────────────────────
    try writer.writeAll(
        "#set text(\n" ++
        "  font: (\"Source Sans Pro\", \"Helvetica\", \"Arial\"),\n" ++
        "  size: 11pt,\n" ++
        "  lang: \"en\",\n" ++
        ")\n\n",
    );

    // Monospace font for code / raw.
    try writer.writeAll(
        "#show raw: set text(font: (\"Source Code Pro\", \"Courier New\", \"monospace\"))\n\n",
    );

    // Code-block styling — light grey background, matches eisvogel's listings style.
    try writer.writeAll(
        "#show raw.where(block: true): it => block(\n" ++
        "  fill: rgb(\"#F7F7F7\"),\n" ++
        "  inset: 10pt,\n" ++
        "  radius: 4pt,\n" ++
        "  width: 100%,\n" ++
        "  stroke: 0.5pt + rgb(\"#DDDDDD\"),\n" ++
        "  it,\n" ++
        ")\n\n",
    );

    // Heading styling — dark charcoal, matches eisvogel `#282828`.
    try writer.writeAll(
        "#show heading: it => {\n" ++
        "  set text(fill: rgb(\"#282828\"))\n" ++
        "  it\n" ++
        "}\n\n",
    );

    // Link colour — matches eisvogel default hyperref red.
    try writer.writeAll("#show link: set text(fill: rgb(\"#A50000\"))\n\n");

    // Figure caption styling.
    try writer.writeAll(
        "#show figure.caption: it => {\n" ++
        "  set text(fill: rgb(\"#777777\"), size: 9pt)\n" ++
        "  it\n" ++
        "}\n\n",
    );

    // Alternating table row colours, matching eisvogel `table-use-row-colors`.
    try writer.writeAll(
        "#set table(\n" ++
        "  fill: (_, row) => if row == 0 { rgb(\"#EEEEEE\") }" ++
        " else if calc.odd(row) { white } else { rgb(\"#F7F7F7\") },\n" ++
        "  stroke: rgb(\"#999999\"),\n" ++
        ")\n\n",
    );

    // ── Title page ────────────────────────────────────────────────────────────
    // White background (eisvogel default), coloured rule, logo bottom-left.
    try writer.writeAll("// ── Title page ─────────────────────────────────────────────────────────\n");
    try writer.writeAll("#page(\n  margin: (x: 2.5cm, y: 2.5cm),\n  header: none,\n  footer: none,\n");
    if (opts.is_draft) {
        try writer.writeAll("  background: _pp_draft_bg,\n");
    }
    try writer.writeAll(")[\n");

    // Fixed top padding so the title block appears in the upper-middle area.
    try writer.writeAll("  #v(3cm)\n\n");

    // Title
    try writer.writeAll("  #text(size: 36pt, weight: \"bold\")[");
    try writeEscaped(writer, opts.title);
    try writer.writeAll("]\n\n");

    // Version
    try writer.writeAll("  #v(0.5cm)\n  #text(size: 18pt)[Version v");
    try writeEscaped(writer, opts.version);
    try writer.writeAll("]\n\n");

    // Coloured rule
    try writer.print(
        "  #v(1.5cm)\n  #line(length: 100%, stroke: 4pt + rgb(\"#{s}\"))\n\n",
        .{opts.color},
    );

    // Author / organisation
    try writer.writeAll("  #text(size: 18pt)[");
    try writeEscaped(writer, opts.author);
    try writer.writeAll("]\n\n");

    // Push logo and last-reviewed to the bottom of the page.
    try writer.writeAll("  #v(1fr)\n\n");

    // Logo (bottom-left, 6 cm wide — matches eisvogel `logo-width=6cm`).
    if (opts.logo_rel) |logo| {
        try writer.writeAll("  #image(\"");
        try writeStringLit(writer, logo);
        try writer.writeAll("\", width: 6cm)\n\n");
    }

    // Last reviewed date
    try writer.writeAll("  #text(size: 11pt)[Last Reviewed: ");
    try writeEscaped(writer, opts.last_reviewed);
    try writer.writeAll("]\n]\n\n");

    // ── Table of contents ─────────────────────────────────────────────────────
    try writer.writeAll(
        "#outline(\n" ++
        "  title: \"Contents\",\n" ++
        "  depth: 3,\n" ++
        ")\n\n",
    );
}

// ── Version History ───────────────────────────────────────────────────────────

/// Append a "Version History" section with a table built from
/// `extra.major_revisions` in the policy frontmatter.
/// Matches the custom version history page in the eisvogel template.
fn writeVersionHistory(writer: anytype, fm: *zigmark.Frontmatter) !void {
    const revisions_val = fm.get("extra.major_revisions") orelse return;
    const revisions = switch (revisions_val) {
        .array => |a| a.items,
        else => return,
    };
    if (revisions.len == 0) return;

    try writer.writeAll("\n#pagebreak()\n= Version History\n\n");
    try writer.writeAll(
        "#table(\n" ++
        "  columns: (auto, auto, 1fr, auto, auto),\n" ++
        "  align: (center, center, left, center, center),\n" ++
        "  table.header(\n" ++
        "    [*Version*], [*Date*], [*Description*], [*Revised By*], [*Approved By*],\n" ++
        "  ),\n",
    );

    for (revisions) |rev| {
        const obj = switch (rev) {
            .object => |o| o,
            else => continue,
        };

        // Version
        try writer.writeAll("  [");
        if (obj.get("version")) |v| switch (v) {
            .string  => |s| try writeEscaped(writer, s),
            .float   => |f| try writer.print("{d}", .{f}),
            .integer => |n| try writer.print("{d}", .{n}),
            else => {},
        };
        try writer.writeAll("],\n");

        // Date
        try writer.writeAll("  [");
        if (obj.get("date")) |v| switch (v) {
            .string => |s| try writeEscaped(writer, s),
            else    => {},
        };
        try writer.writeAll("],\n");

        // Description
        try writer.writeAll("  [");
        if (obj.get("description")) |v| switch (v) {
            .string => |s| try writeEscaped(writer, s),
            else    => {},
        };
        try writer.writeAll("],\n");

        // Revised by
        try writer.writeAll("  [");
        if (obj.get("revised_by")) |v| switch (v) {
            .string => |s| try writeEscaped(writer, s),
            else    => {},
        };
        try writer.writeAll("],\n");

        // Approved by
        try writer.writeAll("  [");
        if (obj.get("approved_by")) |v| switch (v) {
            .string => |s| try writeEscaped(writer, s),
            else    => {},
        };
        try writer.writeAll("],\n");
    }

    try writer.writeAll(")\n");
}

// ── Filename helpers ──────────────────────────────────────────────────────────

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

// ── typst subprocess ──────────────────────────────────────────────────────────

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

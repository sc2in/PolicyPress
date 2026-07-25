//! Copyright © 2026 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 OR PolyForm-Internal-Use-1.0.0
//!
//! Typst-based PDF compiler — replaces the Pandoc/xelatex pipeline.
//!
//! Pipeline:
//!   Markdown → shortcode pre-processing → zigmark AST → Typst markup
//!            → `typst compile` → PDF
//!
//! Mermaid diagrams are rendered in-process to SVG by pozeiden and embedded
//! inline in the Typst source — no mermaid-filter, node, or Chromium.
//!
//! The generated PDF matches the eisvogel/policypress pandoc output:
//!   - Title page: logo (bottom-left), title, version, org, last-reviewed,
//!     coloured rule
//!   - Header: "Title vX.Y" (left) + logo (right)
//!   - Footer: "Org © Year" | "Confidential" | page number
//!   - Table of contents
//!   - Body (with █-bar redactions when --redact)
//!   - Version History table (from extra.major_revisions frontmatter)
//!   - draft.png page background on every page when --draft
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const EnvMap = std.process.Environ.Map;

const annex = @import("control_annex");
const clap = @import("clap");
const Config = @import("config").Config;
const pozeiden = @import("pozeiden");
const u = @import("utils");
const zigmark = @import("zigmark");

const fonts = @import("fonts.zig");

pub const std_options: std.Options = .{
    .log_level = .warn,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .parser, .level = .warn },
        .{ .scope = .typst, .level = .warn },
        .{ .scope = .yaml, .level = .err },
    },
    .logFn = u.logFn,
};

const log = std.log.scoped(.typst);

/// Options for the shared document setup (metadata, page layout, fonts, show
/// rules). Subset of `DocOpts`; also used directly by the report PDFs.
pub const SetupOpts = struct {
    title: []const u8,
    /// Running page header, e.g. "Policy Name vX.Y" or the report title.
    header_title: []const u8,
    author: []const u8,
    /// Root-absolute Typst path to the logo ("/static/logo.png"), or null to omit.
    logo: ?[]const u8,
    /// Root-absolute Typst path to draft.png, or null when not a draft build.
    draft_bg: ?[]const u8 = null,
    footer_left: []const u8,
    /// Classification shown centred in the footer (e.g. "Confidential").
    footer_center: []const u8,
};

/// Options for the shared title page. Subset of `DocOpts`, generalised for
/// non-policy documents: reports have no version and show a "Generated" date
/// instead of "Last Reviewed".
pub const TitleOpts = struct {
    title: []const u8,
    /// Version shown under the title as "Version vX.Y"; null omits the line.
    version: ?[]const u8,
    /// Six-digit hex colour (no `#` prefix) for the title-page rule.
    color: []const u8,
    author: []const u8,
    logo: ?[]const u8,
    draft_bg: ?[]const u8 = null,
    /// Bottom-of-page date line: label ("Last Reviewed: ", "Generated: ")
    /// followed by the value.
    date_label: []const u8,
    date_value: []const u8,
    redact: bool = false,
};

/// Options for the policypress-specific Typst preamble.
const DocOpts = struct {
    /// Full title shown on the title page (may include "(Redacted)"/"(Draft)" suffixes).
    title: []const u8,
    /// Running page header: "Policy Name vX.Y" (no suffixes).
    header_title: []const u8,
    author: []const u8,
    /// Six-digit hex colour (no `#` prefix) for the title-page rule.
    color: []const u8,
    /// Root-absolute Typst path to the logo ("/static/logo.png"), or null to omit.
    logo: ?[]const u8,
    /// Root-absolute Typst path to draft.png, or null when not a draft build
    /// (or the watermark image is missing).
    draft_bg: ?[]const u8,
    footer_left: []const u8,
    /// Classification shown centred in the footer (e.g. "Confidential").
    footer_center: []const u8,
    version: []const u8,
    last_reviewed: []const u8,
    /// Whether this is a redacted build. Adds an in-document "REDACTED" banner
    /// to the title page so a printed redacted PDF is self-identifying, not just
    /// distinguishable by filename.
    redact: bool = false,
    /// Whether the body contains TeX math (opt-in via per-policy `extra.math`,
    /// and the doc actually has math). When true the preamble imports mitex and
    /// sets a document-wide equation alt-text fallback for PDF/UA-1.
    math: bool = false,
};

/// A fully rendered policy: the Typst source and the sanitised PDF filename.
pub const Rendered = struct {
    /// Complete Typst source (preamble + body + version-history table).
    source: []u8,
    /// Sanitised output PDF filename, e.g. "Test_Policy_-_v1.1.pdf".
    pdf_name: []u8,

    pub fn deinit(self: *Rendered, a: Allocator) void {
        a.free(self.source);
        a.free(self.pdf_name);
    }
};

/// Compile a single Markdown policy file to PDF via the Typst engine.
/// Drop-in replacement for `pandoc.compile`.
pub fn compile(
    io: std.Io,
    env: *EnvMap,
    alloc: Allocator,
    config: Config,
    input_file: []const u8,
    /// Control-footnote resolver (from `controls.ControlJoin`), or null to leave
    /// footnote references undefined. Read-only, so it is safe to copy into each
    /// concurrent compile task.
    resolver: ?zigmark.footnotes.Resolver,
    /// Control-coverage annex provider (from `controls.ControlJoin`), or null to
    /// omit the annex entirely (byte-identical to the pre-#165 output). Also
    /// read-only and copy-safe across the compile tasks.
    annex_provider: ?annex.Provider,
) !void {
    var rendered = try renderWithControls(io, alloc, config, input_file, resolver, annex_provider);
    defer rendered.deinit(alloc);

    try compileSource(io, env, alloc, config, rendered.source, std.fs.path.basename(input_file), rendered.pdf_name);
}

/// Compile a complete Typst source string to `<config.build_dir>/<pdf_name>`.
/// `work_hint` only flavours the temporary work-file name for debuggability.
/// Shared by the per-policy `compile` and the report PDFs.
pub fn compileSource(
    io: std.Io,
    env: *EnvMap,
    alloc: Allocator,
    config: Config,
    source: []const u8,
    work_hint: []const u8,
    pdf_name: []const u8,
) !void {
    // ── Write the .typ within --root ─────────────────────────────────────────
    // typst rejects source files outside --root, so the system temp directory
    // is not usable. Write a hidden file at the site root and delete it after
    // compilation. Random suffix: unique per task even within one process, so
    // concurrent compiles of same-named files cannot collide. On the
    // (astronomically unlikely) name collision, retry with a fresh name —
    // never delete a file this run did not create.
    const typ_file, const typ_abs = blk: {
        var attempt: usize = 0;
        while (attempt < 16) : (attempt += 1) {
            var typ_id: u64 = undefined;
            io.random(std.mem.asBytes(&typ_id));
            const typ_name = try std.fmt.allocPrint(alloc, ".pp_{x}_{s}.typ", .{ typ_id, work_hint });
            defer alloc.free(typ_name);
            const abs = try std.fs.path.join(alloc, &.{ config.root, typ_name });
            const f = std.Io.Dir.createFileAbsolute(io, abs, .{ .exclusive = true }) catch |e| {
                alloc.free(abs);
                if (e == error.PathAlreadyExists) continue;
                return e;
            };
            break :blk .{ f, abs };
        }
        log.err("could not create a unique .typ work file under {s}\n", .{config.root});
        return error.TypstWorkFileConflict;
    };
    defer alloc.free(typ_abs);
    defer {
        typ_file.close(io);
        std.Io.Dir.deleteFileAbsolute(io, typ_abs) catch {};
    }
    try typ_file.writeStreamingAll(io, source);

    // Verify output directory is still accessible before invoking typst.
    std.Io.Dir.cwd().access(io, config.build_dir, .{}) catch |e| {
        log.err("Could not access build directory: {s}\nError: {}\n", .{ config.build_dir, e });
        return e;
    };

    const out_path = try std.fs.path.join(alloc, &.{ config.build_dir, pdf_name });
    defer alloc.free(out_path);

    try runTypst(io, env, alloc, typ_abs, out_path, config.root, config.pdf_standard);
}

/// Compute the output PDF filename for a policy without rendering it. Used to
/// detect two policies that would resolve to the same filename (same title +
/// version) before compilation, which would otherwise race to the same path
/// and silently overwrite one another. Caller owns the returned slice.
pub fn outputName(io: std.Io, alloc: Allocator, config: Config, input_file: []const u8) ![]u8 {
    var dir = try std.Io.Dir.cwd().openDir(io, config.root, .{});
    defer dir.close(io);
    var file = try dir.openFile(io, input_file, .{ .mode = .read_only });
    defer file.close(io);

    const raw = try u.readAllAlloc(io, file, alloc, u.max_policy_bytes);
    var contents = Array(u8){ .items = raw, .capacity = raw.len };
    defer contents.deinit(alloc);

    var fm = try u.get_metadata(alloc, &contents, config);
    defer fm.deinit(alloc);
    return fm.filename(alloc);
}

/// Render a Markdown policy file to a complete Typst source. Split out from
/// `compile` so tests can assert on the generated markup without a typst
/// binary. Caller owns the result (free via `Rendered.deinit`).
///
/// This is the control-free path: footnote references are left unresolved, so
/// output is byte-identical to the pre-#164 renderer (the golden baselines
/// depend on this). Pass a resolver via `renderWithControls` to synthesise
/// control footnotes.
pub fn render(
    io: std.Io,
    alloc: Allocator,
    config: Config,
    input_file: []const u8,
) !Rendered {
    return renderWithControls(io, alloc, config, input_file, null, null);
}

/// As `render`, but when `resolver` is non-null every undefined footnote
/// reference is offered to it (`zigmark.footnotes.resolve`) between parsing and
/// rendering, so inline control references (`[^IAC-01]`, produced from the
/// `control(...)` shortcode by `replace_control_refs`) become native
/// `#footnote[…]`. A null resolver leaves the AST untouched — byte-identical to
/// the pre-#164 output.
pub fn renderWithControls(
    io: std.Io,
    alloc: Allocator,
    config: Config,
    input_file: []const u8,
    resolver: ?zigmark.footnotes.Resolver,
    annex_provider: ?annex.Provider,
) !Rendered {
    log.debug("Processing markdown file: {s}\n", .{input_file});

    // ── 1. Read source ───────────────────────────────────────────────────────

    var dir = try std.Io.Dir.cwd().openDir(io, config.root, .{});
    defer dir.close(io);
    var file = dir.openFile(io, input_file, .{ .mode = .read_only }) catch |e| {
        if (e == error.FileNotFound) {
            log.err("File: {s}/{s} not found\n", .{ config.root, input_file });
        }
        return e;
    };
    defer file.close(io);

    const raw = try u.readAllAlloc(io, file, alloc, u.max_policy_bytes);
    var contents = Array(u8){
        .items = raw,
        .capacity = raw.len,
    };
    defer contents.deinit(alloc);

    // ── 2. Pre-process shortcodes (same sequence as the pandoc pipeline) ─────

    try u.replace_org(alloc, &contents, config.org);
    // Inline control references: rewrite `{{ control(id="…") }}` to the bare id
    // text for now (footnote synthesis lands in a later subissue). Malformed ids
    // hard-fail here rather than leaking raw shortcode syntax into the PDF.
    try u.replace_control_refs(alloc, &contents);
    try u.replace_zola_at(alloc, &contents, config.base_url);
    // Root-absolute image paths (`/x`, Zola-served from `static/`) must point at
    // `/static/x` for the Typst `--root`, or the image 404s in the PDF. Runs
    // after replace_zola_at so `@/…` links (now full URLs) are already skipped.
    try u.rewrite_image_paths(alloc, &contents);
    try u.replace_admonitions(alloc, &contents);
    try u.replace_mermaid(alloc, &contents);
    // `u.redact` masks redacted spans with solid `█` bars directly (only the
    // spans, never legitimate underscores elsewhere in the body).
    try u.redact(alloc, &contents, config.redact);

    // ── 3. Extract frontmatter ───────────────────────────────────────────────

    var fm = try u.get_metadata(alloc, &contents, config);
    defer fm.deinit(alloc);

    // Parse frontmatter a second time with the zigmark API to get the full
    // major_revisions array (u.get_metadata only returns the most recent version).
    var raw_fm = try zigmark.Frontmatter.initFromMarkdown(alloc, contents.items);
    defer raw_fm.deinit();

    // ── 4. Parse Markdown → AST ──────────────────────────────────────────────

    // Opt-in TeX math: a per-policy `extra.math: true` enables it, mirroring the
    // web KaTeX gate (templates/macros/math.html reads `page.extra.math`). Off by
    // default, so zigmark's output — and every existing golden — is unchanged.
    const math_on: bool = if (raw_fm.get("extra.math")) |v|
        v == .bool and v.bool
    else
        false;

    var parser = zigmark.Parser.init();
    parser.math = math_on;
    defer parser.deinit(alloc);
    var doc = try parser.parseMarkdown(alloc, contents.items);
    defer doc.deinit(alloc);

    // Synthesise control-footnote definitions for the `[^ID]` references that
    // `replace_control_refs` produced from `control(...)` shortcodes. Only when a
    // resolver is supplied — a null resolver leaves the AST (and every existing
    // golden) byte-identical. Uses the same parser flags so a synthesised body
    // parses like the host document.
    if (resolver) |r| {
        _ = try zigmark.footnotes.resolve(alloc, &doc, r, .{ .parser = parser });
    }

    // Only pull in mitex when math is both enabled and actually present, so a
    // policy that opts in but writes no `$…$` still produces a mitex-free PDF.
    const has_math = math_on and zigmark.docHasMath(&doc);

    // ── 5. Build Typst source ────────────────────────────────────────────────

    const color = validatedColor(config);

    const footer_left = try std.fmt.allocPrint(
        alloc,
        "{s} \u{00a9} {d}",
        .{ config.org, config.current_year },
    );
    defer alloc.free(footer_left);

    // The PDF displays the clean policy title (no "(Redacted)"/"(Draft)"
    // suffixes). fm.title (with suffixes) is only used for the output filename.
    const raw_title: []const u8 = blk: {
        if (raw_fm.get("title")) |v| {
            if (v == .string) break :blk v.string;
        }
        break :blk fm.title;
    };

    // Running header: "Policy Name v1.1" for at-a-glance identification.
    const header_title = try std.fmt.allocPrint(alloc, "{s} v{s}", .{ raw_title, fm.most_recent_version });
    defer alloc.free(header_title);

    // Footer classification: a per-policy `extra.classification` overrides the
    // site default (`config.classification`, itself "Confidential" unless set).
    // Borrowed from raw_fm/config, both alive until the source is materialised.
    const footer_center: []const u8 = blk: {
        if (raw_fm.get("extra.classification")) |v| {
            if (v == .string and v.string.len > 0) break :blk v.string;
        }
        break :blk config.classification;
    };

    const logo: ?[]u8 = try resolveLogoPath(io, alloc, config);
    defer if (logo) |l| alloc.free(l);

    // Draft watermark: keep the pandoc pipeline's draft.png behaviour
    // (site-root static/ wins, theme fallback, warn+skip when absent).
    const draft_bg: ?[]u8 = blk: {
        if (!config.is_draft) break :blk null;
        const abs = (try resolveDraftPng(io, alloc, config)) orelse break :blk null;
        defer alloc.free(abs);
        const tail = std.mem.trimStart(u8, abs[config.root.len..], "/");
        break :blk try std.fmt.allocPrint(alloc, "/{s}", .{tail});
    };
    defer if (draft_bg) |d| alloc.free(d);

    // Render the Markdown body to Typst markup (body only, no preamble),
    // converting mermaid fenced blocks to inline SVG via pozeiden.
    var aw: std.Io.Writer.Allocating = .init(alloc);
    defer aw.deinit();

    try writePreamble(&aw.writer, .{
        .title = raw_title,
        .header_title = header_title,
        .author = config.org,
        .color = color,
        .logo = logo,
        .draft_bg = draft_bg,
        .footer_left = footer_left,
        .footer_center = footer_center,
        .version = fm.most_recent_version,
        .last_reviewed = fm.last_reviewed,
        .redact = config.redact,
        .math = has_math,
    });
    try zigmark.renderTypstWithMermaid(alloc, &aw.writer, doc, &renderMermaid);
    try writeVersionHistory(&aw.writer, &raw_fm);
    // Control Coverage annex: frontmatter framework tags + scope exclusions have
    // no in-text anchor, so they render as an end-of-document annex rather than
    // as (anchorless) footnotes. Emitted only when a provider is supplied — the
    // golden default path (null) stays byte-identical.
    if (annex_provider) |p| try writeControlAnnex(&aw.writer, &raw_fm, p);

    const typ_src = try aw.toOwnedSlice();
    errdefer alloc.free(typ_src);

    // ── 6. Output filename ────────────────────────────────────────────────────
    // fm.filename applies the canonical sanitiser (u.sanitizePdfName); no
    // second pass here, so the name always matches what the site links to.

    const out = try fm.filename(alloc);
    errdefer alloc.free(out);

    return .{ .source = typ_src, .pdf_name = out };
}

/// The configured `pdf_color` validated as a bare hex colour (leading `#`
/// stripped). The colour is interpolated raw into `rgb("#…")` in the preamble,
/// so a stray `"` or `)` in `pdf_color` would otherwise break out of the call
/// and inject arbitrary Typst (which can read files within --root). Falls back
/// to black (with a warning) on anything unexpected.
pub fn validatedColor(config: Config) []const u8 {
    const c = if (config.color.len > 0 and config.color[0] == '#') config.color[1..] else config.color;
    if (isHexColor(c)) return c;
    log.warn("pdf_color '{s}' is not a valid hex colour (expected 3/4/6/8 hex digits); using 000000\n", .{config.color});
    return "000000";
}

/// The logo as a root-absolute Typst path ("/static/logo.png"): Typst resolves
/// leading-`/` paths against --root, independent of the .typ location. Null
/// (skip the logo) when the file is absent or outside the root. Caller frees.
pub fn resolveLogoPath(io: std.Io, alloc: Allocator, config: Config) !?[]u8 {
    if (!std.mem.startsWith(u8, config.logo_path, config.root)) return null;
    std.Io.Dir.accessAbsolute(io, config.logo_path, .{}) catch return null;
    const tail = std.mem.trimStart(u8, config.logo_path[config.root.len..], "/");
    return try std.fmt.allocPrint(alloc, "/{s}", .{tail});
}

// ── Mermaid rendering (pozeiden) ──────────────────────────────────────────────

/// `zigmark.MermaidRendererFn` adapter around pozeiden, called concurrently
/// from the policy compile tasks (pozeiden is thread-safe as of the pinned
/// commit: threadlocal theme state, locked grammar-cache init). The font is
/// overridden to Source Sans 3 (bundled with the binary and passed to typst via
/// --font-path) so Typst can resolve the SVG text (pozeiden's default is
/// "trebuchet ms", which is never available). Errors are logged and propagated
/// — zigmark then falls back to
/// rendering the diagram source as a plain code block.
fn renderMermaid(alloc: Allocator, source: []const u8) anyerror![]const u8 {
    return pozeiden.renderWithOptions(alloc, source, .{
        .theme_override = .{ .font_family = "Source Sans 3, DejaVu Sans, sans-serif" },
    }) catch |e| {
        log.warn("mermaid diagram failed to render ({s}); emitting it as a code block\n", .{@errorName(e)});
        return e;
    };
}

// ── Draft watermark ───────────────────────────────────────────────────────────

/// Resolve the draft.png watermark image: site-root `static/draft.png` wins,
/// falling back to `themes/policypress/static/draft.png` (submodule layout).
/// Returns null (with a warning) when neither exists. Caller frees the result.
pub fn resolveDraftPng(io: std.Io, a: Allocator, config: Config) !?[]u8 {
    const primary = try std.fs.path.join(a, &.{ config.root, "static", "draft.png" });
    if (std.Io.Dir.accessAbsolute(io, primary, .{})) |_| {
        return primary;
    } else |err| switch (err) {
        error.FileNotFound => a.free(primary),
        else => {
            a.free(primary);
            return err;
        },
    }

    // When policypress is used as a Zola theme (submodule), the watermark
    // lives under themes/policypress/static/ rather than at the site root.
    const fallback = try std.fs.path.join(a, &.{ config.root, "themes", "policypress", "static", "draft.png" });
    if (std.Io.Dir.accessAbsolute(io, fallback, .{})) |_| {
        return fallback;
    } else |err| switch (err) {
        error.FileNotFound => {
            a.free(fallback);
            std.log.warn("draft.png not found at site root or in themes/policypress/static/; draft watermark will be skipped", .{});
            return null;
        },
        else => {
            a.free(fallback);
            return err;
        },
    }
}

// ── Typst escape helpers ──────────────────────────────────────────────────────

/// Write `s` with Typst markup-mode special characters escaped.
pub fn writeEscaped(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '\\' => try writer.writeAll("\\\\"),
            '*' => try writer.writeAll("\\*"),
            '_' => try writer.writeAll("\\_"),
            '`' => try writer.writeAll("\\`"),
            '#' => try writer.writeAll("\\#"),
            '$' => try writer.writeAll("\\$"),
            '@' => try writer.writeAll("\\@"),
            '<' => try writer.writeAll("\\<"),
            '[' => try writer.writeAll("\\["),
            ']' => try writer.writeAll("\\]"),
            '~' => try writer.writeAll("\\~"),
            else => try writer.writeByte(c),
        }
    }
}

/// True when `s` is a bare hex colour (`rgb()`-compatible): 3, 4, 6, or 8 hex
/// digits and nothing else. Guards the raw `rgb("#{s}")` interpolation against
/// Typst injection via a hostile `pdf_color`.
fn isHexColor(s: []const u8) bool {
    if (s.len != 3 and s.len != 4 and s.len != 6 and s.len != 8) return false;
    for (s) |c| if (!std.ascii.isHex(c)) return false;
    return true;
}

test "isHexColor accepts hex triples/sextets and rejects injection" {
    try std.testing.expect(isHexColor("0e90f3"));
    try std.testing.expect(isHexColor("fff"));
    try std.testing.expect(isHexColor("AABBCCDD"));
    try std.testing.expect(!isHexColor(""));
    try std.testing.expect(!isHexColor("0e90f")); // 5 digits
    try std.testing.expect(!isHexColor("\") ; #read")); // injection attempt
    try std.testing.expect(!isHexColor("gggggg"));
}

/// Write `s` inside a Typst string literal (double-quoted). Only `"` and `\`
/// need escaping in this context.
pub fn writeStringLit(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            else => try writer.writeByte(c),
        }
    }
}

// ── Preamble ──────────────────────────────────────────────────────────────────

fn writePreamble(writer: anytype, opts: DocOpts) !void {
    try writeDocSetup(writer, .{
        .title = opts.title,
        .header_title = opts.header_title,
        .author = opts.author,
        .logo = opts.logo,
        .draft_bg = opts.draft_bg,
        .footer_left = opts.footer_left,
        .footer_center = opts.footer_center,
    });

    // Opt-in TeX math. zigmark's Typst renderer emits `#mi(…, alt: …)` /
    // `#mitex(…, alt: …)` (per-equation alt text, which typst's PDF/UA-1 mode
    // requires) but deliberately does not import mitex, so the consumer's
    // preamble must. Emitted here, not in writeDocSetup, so the report PDFs
    // (which share writeDocSetup and have no math) stay mitex-free.
    //
    // This `@preview/mitex:X` line is the single source of truth for the version.
    // flake.nix parses it and asserts the vendored nixpkgs mitex package matches
    // (typst's import is version-exact), so a nixpkgs bump that drifts the two
    // apart fails loudly at flake eval. Bumping the version here means updating
    // the math golden (`zig build update-golden`).
    if (opts.math) {
        try writer.writeAll("#import \"@preview/mitex:0.2.7\": mi, mitex\n\n");
    }
    try writeTitlePage(writer, .{
        .title = opts.title,
        .version = opts.version,
        .color = opts.color,
        .author = opts.author,
        .logo = opts.logo,
        .draft_bg = opts.draft_bg,
        .date_label = "Last Reviewed: ",
        .date_value = opts.last_reviewed,
        .redact = opts.redact,
    });
    try writeOutline(writer);
}

/// Shared document setup: metadata, image-alt fallback, page layout with
/// running header/footer, fonts, and show rules. Byte-identical to the policy
/// preamble's first section; reused by the report PDFs.
pub fn writeDocSetup(writer: anytype, opts: SetupOpts) !void {
    // ── Document metadata ────────────────────────────────────────────────────
    try writer.writeAll("#set document(\n  title: \"");
    try writeStringLit(writer, opts.title);
    try writer.writeAll("\",\n  author: \"");
    try writeStringLit(writer, opts.author);
    try writer.writeAll("\",\n)\n\n");

    // Fallback alt text for every image lacking an explicit `alt:` — makes the
    // mermaid `image(bytes(...))` emission (and any future images) satisfy
    // PDF/UA-1's "every image needs alt text" rule without touching zigmark.
    // Harmless in a plain (non-ua-1) compile. A meaningful per-diagram label is
    // an upstream follow-up (see diagrams.zig / the ua-1 guide).
    try writer.writeAll("#set image(alt: \"Diagram\")\n\n");

    // ── Draft watermark helper (reused on body pages and the title page) ─────
    // Full-page draft.png background, matching the pandoc pipeline's
    // page-background variable. The PNG's own alpha carries the opacity.
    if (opts.draft_bg) |bg| {
        try writer.writeAll("#let _pp_draft_bg = place(center + horizon, image(\"");
        try writeStringLit(writer, bg);
        try writer.writeAll("\", width: 100%))\n\n");
    }

    // ── Page layout (body pages) ─────────────────────────────────────────────
    try writer.writeAll("#set page(\n  paper: \"us-letter\",\n  margin: (x: 2.5cm, y: 2.5cm),\n");

    if (opts.draft_bg != null) {
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
    if (opts.logo) |logo| {
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

    // ── Text / font settings ─────────────────────────────────────────────────
    // Source Sans 3 (body) and Source Code Pro (mono) are embedded in the binary
    // and passed to typst via --font-path (see fonts.zig / runTypst), so they
    // always resolve. Only bundled/typst-embedded families are named to keep a
    // bare compile warning-free; typst still auto-falls-back to its embedded
    // fonts for any glyph these lack. "DejaVu Sans Mono" is one of typst's
    // built-in fonts, kept as an explicit monospace fallback for code.
    try writer.writeAll(
        "#set text(\n" ++
            "  font: \"Source Sans 3\",\n" ++
            "  size: 11pt,\n" ++
            "  lang: \"en\",\n" ++
            ")\n\n",
    );

    // Monospace font for code / raw.
    try writer.writeAll(
        "#show raw: set text(font: (\"Source Code Pro\", \"DejaVu Sans Mono\"))\n\n",
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
}

/// Shared title page: coloured rule, org, logo bottom-left, and a date line.
/// The title is emitted as a real level-1 heading so body `==` headings are
/// consecutive (a PDF/UA-1 requirement); see the inline comment.
pub fn writeTitlePage(writer: anytype, opts: TitleOpts) !void {
    // ── Title page ───────────────────────────────────────────────────────────
    // White background (eisvogel default), coloured rule, logo bottom-left.
    try writer.writeAll("// ── Title page ─────────────────────────────────────────────────────────\n");
    try writer.writeAll("#page(\n  margin: (x: 2.5cm, y: 2.5cm),\n  header: none,\n  footer: none,\n");
    if (opts.draft_bg != null) {
        try writer.writeAll("  background: _pp_draft_bg,\n");
    }
    try writer.writeAll(")[\n");

    // Redacted marking: a printed redacted PDF must be self-identifying in the
    // document body, not merely by its filename. A draft build already carries
    // the full-page watermark; this adds an unmistakable title-page banner.
    if (opts.redact) {
        try writer.writeAll(
            "  #align(center)[#box(fill: rgb(\"#c0392b\"), inset: (x: 12pt, y: 6pt), radius: 3pt)[#text(fill: white, weight: \"bold\", size: 14pt, tracking: 2pt)[REDACTED]]]\n" ++
                "  #v(0.5cm)\n\n",
        );
    }

    // Fixed top padding so the title block appears in the upper-middle area.
    try writer.writeAll("  #v(3cm)\n\n");

    // Title — emitted as a real level-1 heading (not styled #text) so the
    // document's heading outline starts at level 1 and the body's `==` headings
    // are consecutive, which PDF/UA-1 requires. `outlined: false` keeps it out
    // of the table of contents; the #show-heading rule below tints it #282828,
    // and the explicit #text size/weight preserves the 36pt bold look.
    try writer.writeAll("  #heading(level: 1, outlined: false)[#text(size: 36pt, weight: \"bold\")[");
    try writeEscaped(writer, opts.title);
    try writer.writeAll("]]\n\n");

    // Version
    if (opts.version) |version| {
        try writer.writeAll("  #v(0.5cm)\n  #text(size: 18pt)[Version v");
        try writeEscaped(writer, version);
        try writer.writeAll("]\n\n");
    }

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
    if (opts.logo) |logo| {
        try writer.writeAll("  #image(\"");
        try writeStringLit(writer, logo);
        try writer.writeAll("\", width: 6cm)\n\n");
    }

    // Date line (policies: "Last Reviewed: <date>"; reports: "Generated: <date>").
    try writer.writeAll("  #text(size: 11pt)[");
    try writeEscaped(writer, opts.date_label);
    try writeEscaped(writer, opts.date_value);
    try writer.writeAll("]\n]\n\n");
}

/// Shared table of contents.
pub fn writeOutline(writer: anytype) !void {
    // ── Table of contents ────────────────────────────────────────────────────
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

    const fields = [_][]const u8{ "version", "date", "description", "revised_by", "approved_by" };
    for (revisions) |rev| {
        const obj = switch (rev) {
            .object => |o| o,
            else => continue,
        };
        for (fields) |field| {
            try writer.writeAll("  [");
            if (obj.get(field)) |v| switch (v) {
                .string => |s| try writeEscaped(writer, s),
                .float => |f| try writer.print("{d}", .{f}),
                .integer => |n| try writer.print("{d}", .{n}),
                else => {},
            };
            try writer.writeAll("],\n");
        }
    }

    try writer.writeAll(")\n");
}

// ── Control Coverage annex ──────────────────────────────────────────────────

/// The frontmatter array under `key`, or null when it is absent or not a list.
fn annexArray(fm: *zigmark.Frontmatter, key: []const u8) ?[]std.json.Value {
    const v = fm.get(key) orelse return null;
    return switch (v) {
        .array => |a| a.items,
        else => null,
    };
}

/// Count the `.string` entries in a frontmatter array (the tagged ids).
fn countStrings(items: ?[]std.json.Value) usize {
    var n: usize = 0;
    if (items) |list| for (list) |it| {
        if (it == .string) n += 1;
    };
    return n;
}

/// Count well-formed scope-exclusion entries (`{ id: str, reason: str }`).
fn countExclusions(items: ?[]std.json.Value) usize {
    var n: usize = 0;
    if (items) |list| for (list) |it| {
        if (it != .object) continue;
        const id = it.object.get("id") orelse continue;
        if (id != .string) continue;
        n += 1;
    };
    return n;
}

/// Append a "Control Coverage" annex: one table per tagged framework present in
/// the frontmatter (SCF and TSC 2017 both show ID | Control/Criterion) plus a
/// "Declared out of scope" subsection listing each `extra.scope_exclusions` id
/// with its reason. Titles come from `provider`; the tag lists come straight
/// from `fm`. Praxis-spine status is intentionally absent — it's an optional
/// overlay (web badges + join.json), not part of this core table. Emits nothing
/// when the policy has no framework tags and no exclusions (output stays
/// byte-identical to a policy without an annex).
fn writeControlAnnex(writer: anytype, fm: *zigmark.Frontmatter, provider: annex.Provider) !void {
    const scf = annexArray(fm, "taxonomies.SCF");
    const tsc = annexArray(fm, "taxonomies.TSC2017");
    const exclusions = annexArray(fm, "extra.scope_exclusions");

    const scf_n = countStrings(scf);
    const tsc_n = countStrings(tsc);
    const excl_n = countExclusions(exclusions);
    if (scf_n == 0 and tsc_n == 0 and excl_n == 0) return;

    try writer.writeAll("\n#pagebreak()\n= Control Coverage\n\n");

    if (scf_n > 0) {
        try writer.writeAll("== SCF\n\n");
        try writer.writeAll(
            "#table(\n" ++
                "  columns: (auto, 1fr),\n" ++
                "  align: (left, left),\n" ++
                "  table.header(\n" ++
                "    [*ID*], [*Control*],\n" ++
                "  ),\n",
        );
        for (scf.?) |item| {
            if (item != .string) continue;
            const id = item.string;
            const info = provider.lookup(.scf, id);
            try writer.writeAll("  [");
            try writeEscaped(writer, id);
            try writer.writeAll("], [");
            if (info.title) |t| try writeEscaped(writer, t) else try writer.writeAll("\u{2014}");
            try writer.writeAll("],\n");
        }
        try writer.writeAll(")\n\n");
    }

    if (tsc_n > 0) {
        try writer.writeAll("== TSC 2017\n\n");
        try writer.writeAll(
            "#table(\n" ++
                "  columns: (auto, 1fr),\n" ++
                "  align: (left, left),\n" ++
                "  table.header(\n" ++
                "    [*ID*], [*Criterion*],\n" ++
                "  ),\n",
        );
        for (tsc.?) |item| {
            if (item != .string) continue;
            const id = item.string;
            const info = provider.lookup(.tsc2017, id);
            try writer.writeAll("  [");
            try writeEscaped(writer, id);
            try writer.writeAll("], [");
            if (info.title) |t| try writeEscaped(writer, t) else try writer.writeAll("\u{2014}");
            try writer.writeAll("],\n");
        }
        try writer.writeAll(")\n\n");
    }

    if (excl_n > 0) {
        try writer.writeAll("== Declared out of scope\n\n");
        try writer.writeAll(
            "#table(\n" ++
                "  columns: (auto, 1fr),\n" ++
                "  align: (left, left),\n" ++
                "  table.header(\n" ++
                "    [*ID*], [*Reason*],\n" ++
                "  ),\n",
        );
        for (exclusions.?) |item| {
            if (item != .object) continue;
            const id_v = item.object.get("id") orelse continue;
            if (id_v != .string) continue;
            try writer.writeAll("  [");
            try writeEscaped(writer, id_v.string);
            try writer.writeAll("], [");
            if (item.object.get("reason")) |r| {
                if (r == .string) try writeEscaped(writer, r.string);
            }
            try writer.writeAll("],\n");
        }
        try writer.writeAll(")\n");
    }
}

// ── typst subprocess ──────────────────────────────────────────────────────────

/// Spawn `typst compile --root <root> --font-path <bundled> <input.typ>
/// <output.pdf>` and wait. The template's fonts (Source Sans 3, Source Code
/// Pro) are embedded in the binary and extracted to `--font-path` by
/// `fonts.ensureFontPath`, so PDF generation is self-contained without a system
/// font install. TYPST_FONT_PATHS from the environment (e.g. the flake
/// devshell) still contributes additional families; typst's embedded fonts are
/// the final fallback.
pub fn runTypst(
    io: std.Io,
    env: *EnvMap,
    a: Allocator,
    input: []const u8,
    output: []const u8,
    root: []const u8,
    pdf_standard: ?[]const u8,
) !void {
    // Work on a private copy of the environment: the build pipeline runs
    // policies concurrently and shares one env map across tasks, so mutating
    // it here (the HOME override below) would be a data race.
    var child_env = try env.clone(a);
    defer child_env.deinit();

    // typst needs a writable HOME/cache dir in some configurations. In the
    // Nix build sandbox HOME is /homeless-shelter (read-only); override with
    // a directory under TMPDIR when the current value is not writable.
    const home_ok = if (child_env.get("HOME")) |h|
        (std.Io.Dir.accessAbsolute(io, h, .{}) catch null) != null
    else
        false;
    if (!home_ok) {
        const tmpdir = child_env.get("TMPDIR") orelse child_env.get("TMP") orelse "/tmp";
        const tmp_home = try std.fmt.allocPrint(a, "{s}/pp-home", .{tmpdir});
        defer a.free(tmp_home);
        std.Io.Dir.cwd().createDirPath(io, tmp_home) catch {};
        try child_env.put("HOME", tmp_home);
        log.debug("HOME not writable - overriding with {s}\n", .{tmp_home});
    }

    // typst requires an absolute --root; config.root already is, but resolve
    // defensively against the cwd when it is not.
    var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
    const root_abs = if (std.fs.path.isAbsolute(root)) root else blk: {
        const cwd_len = try std.process.currentPath(io, &cwd_buf);
        break :blk try std.fs.path.join(a, &.{ cwd_buf[0..cwd_len], root });
    };
    defer if (root_abs.ptr != root.ptr) a.free(root_abs);

    // Point typst at the bundled fonts (extracted once per process). On the
    // unlikely failure to materialise them, fall back to TYPST_FONT_PATHS /
    // typst's embedded fonts rather than aborting the compile.
    const font_dir: ?[]const u8 = fonts.ensureFontPath(io, a, &child_env) catch |e| blk: {
        log.warn("could not extract bundled fonts ({s}); relying on TYPST_FONT_PATHS / embedded fonts\n", .{@errorName(e)});
        break :blk null;
    };

    // Base 4 + optional --font-path (2) + optional --pdf-standard (2) + in/out (2).
    var argv_buf: [10][]const u8 = undefined;
    var argc: usize = 0;
    for ([_][]const u8{ "typst", "compile", "--root", root_abs }) |arg| {
        argv_buf[argc] = arg;
        argc += 1;
    }
    if (font_dir) |fd| {
        argv_buf[argc] = "--font-path";
        argv_buf[argc + 1] = fd;
        argc += 2;
    }
    if (pdf_standard) |std_val| {
        argv_buf[argc] = "--pdf-standard";
        argv_buf[argc + 1] = std_val;
        argc += 2;
    }
    argv_buf[argc] = input;
    argv_buf[argc + 1] = output;
    argc += 2;
    const argv = argv_buf[0..argc];
    log.debug("running: typst compile --root {s} (font-path: {?s}) {s} {s}\n", .{ root_abs, font_dir, input, output });

    // Cap collected output so a runaway process cannot exhaust memory.
    const max_output_bytes = 1024 * 1024;
    const result = std.process.run(a, io, .{
        .argv = argv,
        .environ_map = &child_env,
        .stdout_limit = .limited(max_output_bytes),
        .stderr_limit = .limited(max_output_bytes),
    }) catch |e| {
        if (e == error.FileNotFound) {
            std.debug.print(
                "policypress: typst not found in PATH.\n" ++
                    "Make sure you are running inside the PolicyPress devshell:\n\n" ++
                    "  nix develop github:sc2in/policypress\n\n" ++
                    "or install typst: https://typst.app/open-source/\n\n",
                .{},
            );
            return error.TypstNotFound;
        }
        if (e == error.StreamTooLong) {
            std.debug.print(
                "policypress: typst produced more than {d} bytes of output; aborting this policy.\n",
                .{max_output_bytes},
            );
            return error.TypstFailed;
        }
        std.debug.print("policypress: failed to spawn typst: {s}\n", .{@errorName(e)});
        return e;
    };
    defer a.free(result.stdout);
    defer a.free(result.stderr);

    const exited_ok = switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };

    if (!exited_ok) {
        // Print typst's stderr so the user can see the compile error.
        if (result.stderr.len > 0) {
            std.debug.print("policypress: typst error output:\n{s}\n", .{result.stderr});
        }
        return error.TypstFailed;
    }

    if (result.stderr.len > 0) {
        // typst exited successfully but emitted warnings (e.g. missing font
        // families). Log at warn so they are visible without failing tests.
        log.warn("typst warnings for {s}:\n{s}\n", .{ input, result.stderr });
    }

    log.debug("compiled: {s}\n", .{output});
}

// ── Standalone CLI entry point (`zig build pdf`) ──────────────────────────────

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;
    const env = init.environ_map;

    var config = try Config.load_config_toml(io, alloc);
    defer config.deinit(alloc);

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-d, --draft            Add draft watermark to output.
        \\-r, --redact           Redact text within redaction tags in output.
        \\-o, --output <str>     Destination folder
        \\-i, --input <str>      Input file
    );
    var buf: [128]u8 = undefined;

    var stderr = std.Io.File.stderr().writer(io, &buf).interface;
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, init.minimal.args, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(&stderr, err) catch {};
        return err;
    };
    defer res.deinit();
    if (res.args.help != 0) {
        std.debug.print("PolicyPress PDF Generator (typst engine)\nSee Readme.md to learn more.\n\n", .{});
        return clap.help(&stderr, clap.Help, &params, .{});
    }

    if (res.args.output) |c| {
        log.info("Writing to: {s}\n", .{c});
        config.build_dir = try alloc.dupe(u8, c);
    } else return error.OutputDirNotProvided;

    if (res.args.draft != 0) {
        log.info("Draft mode enabled\n", .{});
        config.is_draft = true;
    }
    if (res.args.redact != 0 or config.redact == true) {
        log.info("Redaction enabled\n", .{});
        config.redact = true;
    }

    log.debug("Running with Configuration:\n{f}\n", .{config});

    if (res.args.input) |w| {
        log.info("Input File: {s}\n", .{w});
        // Standalone CLI: no control join, so no footnote resolver and no annex.
        try compile(io, env, alloc, config, w, null, null);
    } else return error.InputFileNotProvided;
}

//! Copyright © 2026 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 OR PolyForm-Internal-Use-1.0.0
//!
//! Build-time mermaid rendering for the website. Zola's `mermaid` shortcode
//! emits `<pre class="mermaid">…</pre>` placeholders; this pass rewrites them
//! into inline SVG produced in-process by pozeiden (the same renderer the PDF
//! pipeline uses), so the generated site ships no client-side mermaid bundle
//! and diagrams render with JavaScript disabled. See issue #114.
const std = @import("std");
const Allocator = std.mem.Allocator;

const pozeiden = @import("pozeiden");

const log = std.log.scoped(.diagrams);

const open_tag = "<pre class=\"mermaid\">";
const close_tag = "</pre>";

pub const RewriteResult = struct {
    /// Rewritten HTML; caller owns.
    html: []u8,
    /// Number of diagrams rendered.
    count: usize,
};

/// Render a single mermaid diagram source to a self-contained SVG string.
/// Uses the same fonts as the PDF pipeline (see src/typst.zig) so site and PDF
/// diagrams look consistent. Caller owns the returned slice.
pub fn renderSvg(alloc: Allocator, source: []const u8) ![]const u8 {
    return pozeiden.renderWithOptions(alloc, source, .{
        .theme_override = .{ .font_family = "Source Sans 3, DejaVu Sans, sans-serif" },
    });
}

/// Rewrite every `<pre class="mermaid">…</pre>` block in `html` into an inline
/// `<figure class="mermaid-diagram">…SVG…</figure>`. Returns null when the input
/// contains no mermaid block (so the caller can skip rewriting the file). A
/// diagram that fails to render is left as its original `<pre>` block rather
/// than dropped, so the source stays visible.
pub fn rewriteHtml(alloc: Allocator, html: []const u8) !?RewriteResult {
    if (std.mem.indexOf(u8, html, open_tag) == null) return null;

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(alloc);
    var count: usize = 0;
    var i: usize = 0;
    while (std.mem.indexOfPos(u8, html, i, open_tag)) |start| {
        const body_start = start + open_tag.len;
        const close_at = std.mem.indexOfPos(u8, html, body_start, close_tag) orelse break;

        // Everything before this block is copied verbatim.
        try out.appendSlice(alloc, html[i..start]);

        const trimmed = std.mem.trim(u8, html[body_start..close_at], " \t\r\n");
        const source = try unescapeHtml(alloc, trimmed);
        defer alloc.free(source);

        if (renderSvg(alloc, source)) |svg| {
            defer alloc.free(svg);
            // role="img" + a fallback label so assistive tech announces the
            // diagram rather than reading the raw SVG node soup. A meaningful
            // per-diagram label needs alt text from the mermaid source, which is
            // an upstream zigmark/pozeiden follow-up.
            try out.appendSlice(alloc, "<figure class=\"mermaid-diagram\" role=\"img\" aria-label=\"Diagram\">");
            try out.appendSlice(alloc, svg);
            try out.appendSlice(alloc, "</figure>");
            count += 1;
        } else |err| {
            log.warn("mermaid diagram failed to render ({s}); leaving source in place", .{@errorName(err)});
            try out.appendSlice(alloc, html[start .. close_at + close_tag.len]);
        }
        i = close_at + close_tag.len;
    }
    try out.appendSlice(alloc, html[i..]);

    if (count == 0) {
        out.deinit(alloc);
        return null;
    }
    return .{ .html = try out.toOwnedSlice(alloc), .count = count };
}

/// HTML-unescape the entities Zola emits when auto-escaping a shortcode body.
/// Caller owns the returned slice.
fn unescapeHtml(alloc: Allocator, s: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(alloc);
    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '&') {
            if (std.mem.startsWith(u8, s[i..], "&amp;")) {
                try out.append(alloc, '&');
                i += 5;
                continue;
            } else if (std.mem.startsWith(u8, s[i..], "&lt;")) {
                try out.append(alloc, '<');
                i += 4;
                continue;
            } else if (std.mem.startsWith(u8, s[i..], "&gt;")) {
                try out.append(alloc, '>');
                i += 4;
                continue;
            } else if (std.mem.startsWith(u8, s[i..], "&quot;")) {
                try out.append(alloc, '"');
                i += 6;
                continue;
            } else if (std.mem.startsWith(u8, s[i..], "&#39;") or std.mem.startsWith(u8, s[i..], "&#x27;")) {
                try out.append(alloc, '\'');
                i += if (s[i + 2] == 'x') 6 else 5;
                continue;
            }
        }
        try out.append(alloc, s[i]);
        i += 1;
    }
    return out.toOwnedSlice(alloc);
}

/// Recursively rewrite mermaid blocks in every `*.html` under `dir_path`.
/// Returns the total number of diagrams rendered across the tree.
pub fn renderDir(io: std.Io, alloc: Allocator, dir_path: []const u8) !usize {
    var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true, .access_sub_paths = true }) catch |err| {
        log.err("cannot open '{s}': {s}", .{ dir_path, @errorName(err) });
        return err;
    };
    defer dir.close(io);

    var walker = try dir.walk(alloc);
    defer walker.deinit();

    var total: usize = 0;
    var files: usize = 0;
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".html")) continue;

        const html = dir.readFileAlloc(io, entry.path, alloc, .limited(50 * 1024 * 1024)) catch |err| {
            log.warn("cannot read '{s}': {s}", .{ entry.path, @errorName(err) });
            continue;
        };
        defer alloc.free(html);

        const result = rewriteHtml(alloc, html) catch |err| {
            log.warn("cannot process '{s}': {s}", .{ entry.path, @errorName(err) });
            continue;
        } orelse continue;
        defer alloc.free(result.html);

        dir.writeFile(io, .{ .sub_path = entry.path, .data = result.html }) catch |err| {
            log.warn("cannot write '{s}': {s}", .{ entry.path, @errorName(err) });
            continue;
        };
        total += result.count;
        files += 1;
    }
    if (total > 0) {
        log.info("rendered {d} mermaid diagram(s) across {d} file(s) in '{s}'", .{ total, files, dir_path });
    } else {
        log.info("no mermaid diagrams found under '{s}'", .{dir_path});
    }
    return total;
}

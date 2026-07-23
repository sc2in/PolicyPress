//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const builtin = @import("builtin");

const mvzr = @import("mvzr");
const zigmark = @import("zigmark");

const panlog = std.log.scoped(.pandoc);

// ── Input-read byte caps ───────────────────────────────────────────────────────
// Centralised limits so a malformed or hostile file cannot drive an unbounded
// read/allocation. Sized to realistic inputs, not to the filesystem.

/// A `config.toml` is a small hand-written file.
pub const max_config_bytes: usize = 1 << 20; // 1 MiB
/// A single policy Markdown file. Capped at zigmark's own 16 MiB parser ceiling
/// — a larger file could not be parsed anyway — replacing the former 100 MB reads.
pub const max_policy_bytes: usize = 16 << 20; // 16 MiB
/// A generated site HTML page (mermaid rewrite pass reads whole files).
pub const max_html_bytes: usize = 50 << 20; // 50 MiB

/// Custom logging function that prints log messages depending on the log level and scope.
pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    switch (scope) {
        .parser => {},
        else => switch (level) {
            inline else => std.debug.print(format, args),
        },
    }
}

pub const FrontMatter = struct {
    title: []u8,
    most_recent_version: []u8,
    last_reviewed: []u8,
    /// Formats the front matter information and writes it to the provided writer.
    pub fn format(self: FrontMatter, writer: *std.Io.Writer) !void {
        try writer.print(
            "{s}\n\tVersion: {s}\tLast Reviewed: {s}\n",
            .{
                self.title,
                self.most_recent_version,
                self.last_reviewed,
            },
        );
    }
    /// Generates a PDF filename from the title and most recent version in the
    /// front matter. This is the single source of truth for PDF names; the site
    /// templates mirror the same rule via the `pdf_filename` macro so that the
    /// links they build resolve to the files produced here. Does not mutate the
    /// front matter (an earlier version aliased and rewrote `self.title`).
    pub fn filename(self: FrontMatter, a: Allocator) ![]u8 {
        const name = try std.fmt.allocPrint(a, "{s}_-_v{s}.pdf", .{ self.title, self.most_recent_version });
        sanitizePdfName(name);
        return name;
    }

    pub fn deinit(self: *FrontMatter, a: Allocator) void {
        a.free(self.title);
        a.free(self.last_reviewed);
        a.free(self.most_recent_version);
    }
};

/// Canonical PDF-filename sanitiser, applied in-place. This is the one rule the
/// whole toolchain agrees on; the `pdf_filename` Tera macro replicates it so the
/// site's download links match the files this binary writes.
///
/// Rule: any character that is not ASCII-alphanumeric, `_`, `-`, or `.` becomes
/// `_` (so spaces, `/`, `(`, `&`, `?`, quotes, etc. are all normalised). A
/// leading `.` and any doubled `.` are defused so the name can never be `.`,
/// `..`, or a hidden dotfile.
pub fn sanitizePdfName(name: []u8) void {
    var prev_dot = false;
    for (name, 0..) |*ch, i| {
        var c = ch.*;
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-' and c != '.') c = '_';
        if (c == '.') {
            if (i == 0 or prev_dot) {
                c = '_';
                prev_dot = false;
            } else prev_dot = true;
        } else prev_dot = false;
        ch.* = c;
    }
}

/// Parses front matter from a markdown file using zigmark, extracts document
/// metadata, and returns a FrontMatter struct.  Handles YAML, TOML, JSON, and
/// ZON front matter; resolves empty arrays without errors (fixes #73).
/// Normalise a revision's `version` into `buf` as a string. zigmark's YAML
/// parser returns quoted scalars as `.string` and unquoted numerics as
/// `.float`/`.integer`, so all three are accepted. Returns null when absent
/// or an unsupported type.
fn revisionVersion(obj: anytype, buf: []u8) ?[]const u8 {
    return switch (obj.get("version") orelse return null) {
        .string => |s| s,
        .float => |f| std.fmt.bufPrint(buf, "{d}", .{f}) catch null,
        .integer => |n| std.fmt.bufPrint(buf, "{d}", .{n}) catch null,
        else => null,
    };
}

/// A revision's `date` as a string (ISO `YYYY-MM-DD`), or null when absent or
/// not a string. ISO dates order correctly under a plain byte comparison.
fn revisionDate(obj: anytype) ?[]const u8 {
    return switch (obj.get("date") orelse return null) {
        .string => |s| s,
        else => null,
    };
}

/// Order two dotted version strings numerically ("1.9" < "1.10", "9.0" <
/// "10.0"). Segments that are not integers fall back to a byte comparison so a
/// version like "1.0-rc1" still orders deterministically. Returns the order of
/// `x` relative to `y`.
fn compareVersions(x: []const u8, y: []const u8) std.math.Order {
    var xi = std.mem.splitScalar(u8, x, '.');
    var yi = std.mem.splitScalar(u8, y, '.');
    while (true) {
        const xs = xi.next();
        const ys = yi.next();
        if (xs == null and ys == null) return .eq;
        // A missing trailing segment counts as 0 so "1.0" == "1".
        const x_seg = std.mem.trim(u8, xs orelse "0", " ");
        const y_seg = std.mem.trim(u8, ys orelse "0", " ");
        const x_num = std.fmt.parseInt(u64, x_seg, 10) catch {
            const ord = std.mem.order(u8, x_seg, y_seg);
            if (ord != .eq) return ord;
            continue;
        };
        const y_num = std.fmt.parseInt(u64, y_seg, 10) catch {
            const ord = std.mem.order(u8, x_seg, y_seg);
            if (ord != .eq) return ord;
            continue;
        };
        if (x_num != y_num) return if (x_num < y_num) .lt else .gt;
    }
}

/// True when revision `new` is more recent than `cur`. Primary key is the
/// `date` (matching the site, which sorts revisions by date); ties (or missing
/// dates) fall back to a numeric version comparison. This keeps the PDF's
/// version label in agreement with the website and never lets "1.10" lose to
/// "1.9" under a lexicographic compare.
/// The most recent object entry of an `extra.major_revisions` array — by date
/// with a numeric-version tiebreak, the same ordering the site and PDF use —
/// or null when no entry is an object. Shared by the PDF metadata and the
/// policy-review report.
pub fn newestRevision(revisions: []const std.json.Value) ?std.json.ObjectMap {
    var most: ?std.json.ObjectMap = null;
    for (revisions) |rev| {
        const obj = switch (rev) {
            .object => |o| o,
            else => continue,
        };
        if (most == null or revisionIsNewer(obj, most.?)) most = obj;
    }
    return most;
}

fn revisionIsNewer(new_obj: anytype, cur_obj: anytype) bool {
    const new_date = revisionDate(new_obj);
    const cur_date = revisionDate(cur_obj);
    if (new_date != null and cur_date != null) {
        switch (std.mem.order(u8, new_date.?, cur_date.?)) {
            .gt => return true,
            .lt => return false,
            .eq => {},
        }
    }
    var new_buf: [32]u8 = undefined;
    var cur_buf: [32]u8 = undefined;
    const new_ver = revisionVersion(new_obj, &new_buf) orelse return false;
    const cur_ver = revisionVersion(cur_obj, &cur_buf) orelse return true;
    return compareVersions(new_ver, cur_ver) == .gt;
}

test "compareVersions orders dotted versions numerically" {
    try tst.expect(compareVersions("1.9", "1.10") == .lt);
    try tst.expect(compareVersions("1.10", "1.9") == .gt);
    try tst.expect(compareVersions("9.0", "10.0") == .lt);
    try tst.expect(compareVersions("2.0", "2.0") == .eq);
    try tst.expect(compareVersions("2", "2.0") == .eq);
    try tst.expect(compareVersions("2.1", "2") == .gt);
    // A plain lexicographic compare would wrongly rank "1.9" above "1.10".
    try tst.expect(std.mem.order(u8, "1.9", "1.10") == .gt);
}

pub fn get_metadata(a: Allocator, txt: *Array(u8), config: anytype) !FrontMatter {
    var fm = try zigmark.Frontmatter.initFromMarkdown(a, txt.items);
    defer fm.deinit();

    const title_val = fm.get("title") orelse return error.NoTitleInFrontMatter;
    const title_str = switch (title_val) {
        .string => |s| s,
        else => return error.InvalidTitleType,
    };
    panlog.debug("Processing: {s}\n", .{title_str});

    const last_reviewed_val = fm.get("extra.last_reviewed") orelse return error.NoLastReviewInFrontMatter;
    const last_reviewed_str = switch (last_reviewed_val) {
        .string => |s| s,
        else => return error.InvalidLastReviewedType,
    };

    const revisions_val = fm.get("extra.major_revisions") orelse return error.NoRevisionsInFrontMatter;
    const revisions = switch (revisions_val) {
        .array => |arr| arr.items,
        else => return error.InvalidRevisionsType,
    };
    if (revisions.len == 0) return error.NoRevisionsInFrontMatter;

    const most_recent_obj = newestRevision(revisions) orelse return error.InvalidRevisionFormat;
    // zigmark's YAML parser returns quoted numeric scalars (e.g. "1.1") as .float,
    // so accept both .string and numeric variants and normalise to a slice.
    var ver_buf: [32]u8 = undefined;
    const version_str: []const u8 = switch (most_recent_obj.get("version") orelse return error.NoVersionForRevision) {
        .string => |s| s,
        .float => |f| try std.fmt.bufPrint(&ver_buf, "{d}", .{f}),
        .integer => |n| try std.fmt.bufPrint(&ver_buf, "{d}", .{n}),
        else => return error.InvalidVersionType,
    };

    const title = if (config.redact and config.is_draft)
        try std.fmt.allocPrint(a, "{s} (Redacted) (Draft)", .{title_str})
    else if (config.redact)
        try std.fmt.allocPrint(a, "{s} (Redacted)", .{title_str})
    else if (config.is_draft)
        try std.fmt.allocPrint(a, "{s} (Draft)", .{title_str})
    else
        try a.dupe(u8, title_str);

    return .{
        .title = title,
        .last_reviewed = try a.dupe(u8, last_reviewed_str),
        .most_recent_version = try a.dupe(u8, version_str),
    };
}

/// Replaces all instances of the organization placeholder in the markdown text with the actual organization name from the global configuration.
pub fn replace_org(alloc: Allocator, txt: *Array(u8), with: []const u8) !void {
    const orgsc: mvzr.Regex = mvzr.compile("\\{\\{\\s*org\\(\\)\\s*\\}\\}").?;

    if (!orgsc.isMatch(txt.items)) return;

    var new = try txt.clone(alloc);

    var iter = orgsc.iterator(txt.items);
    while (iter.next()) |match| {
        try new.replaceRange(alloc, match.start, match.slice.len, with);
        iter = orgsc.iterator(new.items);
    }
    txt.deinit(alloc);
    txt.* = new;
}

/// PDF pre-pass for inline control references.
///
/// Rewrites every `{{ control(id="IAC-01") }}` shortcode to a Markdown footnote
/// reference (`[^IAC-01]`). The control-ID join (`src/controls.zig`) then
/// synthesises the matching footnote definition — control title + praxis spine
/// status + covering policies — which zigmark's Typst renderer expands into a
/// native `#footnote[…]`. The website renders the same shortcode as a link via
/// templates/shortcodes/control.html.
///
/// Strictness mirrors `redact`'s orphan-tag handling: the id must match
/// `[A-Z]{2,5}-[0-9]{2}(\.[0-9]+)*` exactly. Any `control(` construct that does
/// not form a well-formed shortcode with a valid id is a hard error
/// (`MalformedControlRef`) rather than passed through — a malformed reference
/// that reached the PDF would otherwise render as raw template text.
pub fn replace_control_refs(alloc: Allocator, txt: *Array(u8)) !void {
    // Coarse opener: detects any control shortcode so we can (a) skip the work
    // entirely when there are none and (b) flag leftovers that the strict
    // pattern below did not consume as malformed.
    const opener: mvzr.Regex = mvzr.compile("\\{\\{\\s*control\\(").?;
    if (!opener.isMatch(txt.items)) return;

    // Strict, well-formed reference: `{{ control(id="<ID>") }}` with a valid id.
    const ref: mvzr.Regex = mvzr.compile("\\{\\{\\s*control\\(id=\"[A-Z]{2,5}-[0-9]{2}(\\.[0-9]+)*\"\\)\\s*\\}\\}").?;

    var new = try txt.clone(alloc);

    var iter = ref.iterator(txt.items);
    while (iter.next()) |m| {
        // Pull the id out of the matched slice (between `id="` and the next `"`).
        // The strict regex guarantees these markers exist and bound a valid id.
        const key = "id=\"";
        const s = std.mem.indexOf(u8, m.slice, key) orelse return error.InvalidShortCode;
        const id_start = s + key.len;
        const id_end = std.mem.indexOfScalarPos(u8, m.slice, id_start, '"') orelse return error.InvalidShortCode;
        const id = m.slice[id_start..id_end];

        // Emit a footnote reference `[^<id>]`; controls.zig synthesises the
        // definition so the Typst renderer produces a native `#footnote[…]`.
        const fnref = try std.fmt.allocPrint(alloc, "[^{s}]", .{id});
        defer alloc.free(fnref);

        try new.replaceRange(alloc, m.start, m.slice.len, fnref);
        iter = ref.iterator(new.items);
    }
    txt.deinit(alloc);
    txt.* = new;

    // After rewriting every well-formed reference, any surviving `control(`
    // opener is malformed (bad id, missing id, or unclosed) — hard fail so it
    // never reaches the PDF as literal shortcode text.
    if (opener.isMatch(txt.items)) return error.MalformedControlRef;
}

/// Replaces all instances of the [...](@/...) links in the markdown text with the base_url
/// Example: [Privacy](@/policies/privacy-policy.md) -> [Privacy](https://security.sc2.in/policies/privacy-policy.html)
/// Example: [Acceptable Use](@/policies/aup/) -> [Acceptable Use](https://security.sc2.in/policies/aup/)
/// Example: [Image passthrough](@/policies/aup/image.png) -> [Image passthrough](https://security.sc2.in/policies/aup/image.png)
pub fn replace_zola_at(alloc: Allocator, txt: *Array(u8), base_url: []const u8) !void {
    const at: mvzr.Regex = mvzr.compile("\\]\\(@/.+?\\)").?;
    if (!at.isMatch(txt.items)) return;

    var new = try txt.clone(alloc);

    var iter = at.iterator(txt.items);

    while (iter.next()) |match| {
        const ref = match.slice[4 .. match.slice.len - 1];

        const file = if (std.mem.endsWith(u8, ref, "/_index.md"))
            try alloc.dupe(u8, ref[0 .. ref.len - 9])
        else if (std.mem.endsWith(u8, ref, "/index.md"))
            try alloc.dupe(u8, ref[0 .. ref.len - 8])
        else if (std.mem.endsWith(u8, ref, ".md"))
            try std.fmt.allocPrint(alloc, "{s}.html", .{ref[0 .. ref.len - 3]})
        else
            try alloc.dupe(u8, ref);
        defer alloc.free(file);

        const link = try std.fmt.allocPrint(alloc, "]({s}/{s})", .{
            base_url,
            file,
        });
        defer alloc.free(link);
        try new.replaceRange(alloc, match.start, match.slice.len, link);

        iter = at.iterator(new.items);
    }
    txt.deinit(alloc);
    txt.* = new;
}

test "replace_zola_at" {
    const allocator = tst.allocator;

    var arr = Array(u8).empty;
    defer arr.deinit(allocator);
    try arr.appendSlice(allocator,
        \\[some section](@/policies/privacy/_index.md)
        \\[some dir](@/policies/privacy/index.md)
        \\[some link](@/policies/aup.md)
        \\[an image](@/policies/image.png)
    );

    try replace_zola_at(allocator, &arr, "https://example.com");

    const expected =
        \\[some section](https://example.com/policies/privacy/)
        \\[some dir](https://example.com/policies/privacy/)
        \\[some link](https://example.com/policies/aup.html)
        \\[an image](https://example.com/policies/image.png)
    ;
    try tst.expectEqualStrings(expected, arr.items);
}

/// For the PDF pipeline only: rewrite a Markdown image whose destination is a
/// site-root-absolute path (`![alt](/x)`) to its on-disk location under
/// `static/` (`![alt](/static/x)`).
///
/// Zola serves `static/x` at the web root `/x`, so that is how authors
/// reference images. But the Typst compiler resolves paths against the project
/// root (`--root`), where the file actually lives under `static/`. Without this
/// rewrite an authored image renders on the website but 404s in the PDF.
///
/// External URLs (`http://`, `https://`), protocol-relative `//…`, data URIs,
/// and paths already under `/static/` are left untouched. Deterministic — no
/// filesystem access, so a genuinely missing image surfaces as a clear Typst
/// compile error rather than being silently dropped.
pub fn rewrite_image_paths(alloc: Allocator, txt: *Array(u8)) !void {
    const img: mvzr.Regex = mvzr.compile("!\\[.*?\\]\\(/.*?\\)").?;
    if (!img.isMatch(txt.items)) return;

    var out = Array(u8).empty;
    errdefer out.deinit(alloc);

    var last: usize = 0;
    var iter = img.iterator(txt.items);
    while (iter.next()) |match| {
        try out.appendSlice(alloc, txt.items[last..match.start]);

        // match.slice is "![alt](/dest)"; split at the final "](".
        const open = std.mem.lastIndexOf(u8, match.slice, "](").?;
        const prefix = match.slice[0 .. open + 2]; // "![alt]("
        const dest = match.slice[open + 2 .. match.slice.len - 1]; // "/dest"

        try out.appendSlice(alloc, prefix);
        if (std.mem.startsWith(u8, dest, "/") and
            !std.mem.startsWith(u8, dest, "//") and
            !std.mem.startsWith(u8, dest, "/static/"))
        {
            try out.appendSlice(alloc, "/static");
        }
        try out.appendSlice(alloc, dest);
        try out.appendSlice(alloc, ")");

        last = match.start + match.slice.len;
    }
    try out.appendSlice(alloc, txt.items[last..]);

    txt.deinit(alloc);
    txt.* = out;
}

test "rewrite_image_paths" {
    const allocator = tst.allocator;

    var arr = Array(u8).empty;
    defer arr.deinit(allocator);
    try arr.appendSlice(allocator,
        \\![a diagram](/diagram.png)
        \\![nested](/img/flow.svg)
        \\![already static](/static/logo.png)
        \\![external](https://example.com/x.png)
        \\![protocol relative](//cdn/x.png)
        \\a [normal link](/some-page) stays
    );

    try rewrite_image_paths(allocator, &arr);

    const expected =
        \\![a diagram](/static/diagram.png)
        \\![nested](/static/img/flow.svg)
        \\![already static](/static/logo.png)
        \\![external](https://example.com/x.png)
        \\![protocol relative](//cdn/x.png)
        \\a [normal link](/some-page) stays
    ;
    try tst.expectEqualStrings(expected, arr.items);
}

/// Finds and replaces custom Mermaid code blocks in the markdown with a standardized code block format.
pub fn replace_mermaid(alloc: Allocator, txt: *Array(u8)) !void {
    const mermaid: mvzr.Regex = mvzr.compile("\\{%\\s*mermaid\\(\\)\\s*%\\}.+?\\{%\\s*end\\s*%\\}").?;
    if (!mermaid.isMatch(txt.items)) return;

    var new = try txt.clone(alloc);

    var iter = mermaid.iterator(txt.items);
    while (iter.next()) |m| {
        const s = std.mem.indexOf(u8, m.slice, "%}") orelse return error.InvalidShortCode;
        const e = std.mem.lastIndexOf(u8, m.slice, "{%") orelse return error.InvalidShortCode;
        const inner = m.slice[s + 2 .. e - 1];
        const replace = try std.fmt.allocPrint(alloc, "~~~mermaid{s}\n~~~", .{inner});
        defer alloc.free(replace);

        try new.replaceRange(alloc, m.start, m.slice.len, replace);
        iter = mermaid.iterator(new.items);
    }
    txt.deinit(alloc);
    txt.* = new;
}

pub const MDFile = struct {
    path: []const u8,
    pub fn deinit(_: MDFile, _: Allocator) void {
        // a.free(self.path);
    }
};

/// A calendar date. Replaces the previously-used zig-datetime dependency, which
/// has no Zig 0.16 release; policypress only needs today's year/month/day.
pub const Date = struct {
    year: u16,
    month: u8,
    day: u8,

    /// Today's date from the wall clock, via the std.Io context.
    pub fn today(io: std.Io) Date {
        const secs = std.Io.Timestamp.now(io, .real).toSeconds();
        const es: std.time.epoch.EpochSeconds = .{ .secs = @intCast(secs) };
        const yd = es.getEpochDay().calculateYearDay();
        const md = yd.calculateMonthDay();
        return .{
            .year = yd.year,
            .month = md.month.numeric(),
            .day = @as(u8, md.day_index) + 1,
        };
    }

    /// Parse an ISO `YYYY-MM-DD` date (the format policy front matter uses for
    /// `last_reviewed` and revision dates). Returns null on any malformed input
    /// — callers treat an unparseable date as advisory, not a hard failure.
    /// Only the calendar date is validated (ranges, not weekday); a trailing
    /// time component (e.g. `2025-02-24T00:00:00`) is tolerated and ignored.
    pub fn parse(s: []const u8) ?Date {
        if (s.len < 10) return null;
        if (s[4] != '-' or s[7] != '-') return null;
        const year = std.fmt.parseInt(u16, s[0..4], 10) catch return null;
        const month = std.fmt.parseInt(u8, s[5..7], 10) catch return null;
        const day = std.fmt.parseInt(u8, s[8..10], 10) catch return null;
        if (month < 1 or month > 12) return null;
        const dim = std.time.epoch.getDaysInMonth(year, @enumFromInt(month));
        if (day < 1 or day > dim) return null;
        return .{ .year = year, .month = month, .day = day };
    }

    /// Days since the Unix epoch (1970-01-01) for this calendar date, via
    /// Howard Hinnant's `days_from_civil`. Used to compute review ages in whole
    /// days without pulling in a date-time dependency.
    pub fn epochDay(self: Date) i64 {
        const y: i64 = @as(i64, self.year) - @intFromBool(self.month <= 2);
        const era: i64 = @divFloor(if (y >= 0) y else y - 399, 400);
        const yoe: i64 = y - era * 400; // [0, 399]
        const mp: i64 = @mod(@as(i64, self.month) + 9, 12); // Mar=0..Feb=11
        const doy: i64 = @divTrunc(153 * mp + 2, 5) + @as(i64, self.day) - 1; // [0, 365]
        const doe: i64 = yoe * 365 + @divTrunc(yoe, 4) - @divTrunc(yoe, 100) + doy; // [0, 146096]
        return era * 146097 + doe - 719468;
    }
};

test "Date.parse accepts valid ISO dates and rejects malformed ones" {
    try tst.expectEqual(@as(?Date, .{ .year = 2025, .month = 2, .day = 24 }), Date.parse("2025-02-24"));
    try tst.expectEqual(@as(?Date, .{ .year = 2024, .month = 2, .day = 29 }), Date.parse("2024-02-29")); // leap day
    try tst.expectEqual(@as(?Date, null), Date.parse("2025-02-29")); // not a leap year
    try tst.expectEqual(@as(?Date, null), Date.parse("2025-13-01")); // bad month
    try tst.expectEqual(@as(?Date, null), Date.parse("2025/02/24")); // wrong separator
    try tst.expectEqual(@as(?Date, null), Date.parse("nope"));
}

test "Date.epochDay matches known reference days" {
    try tst.expectEqual(@as(i64, 0), (Date{ .year = 1970, .month = 1, .day = 1 }).epochDay());
    // 2025-02-24 minus 2024-02-24 is a leap year apart == 366 days.
    const a = (Date{ .year = 2024, .month = 2, .day = 24 }).epochDay();
    const b = (Date{ .year = 2025, .month = 2, .day = 24 }).epochDay();
    try tst.expectEqual(@as(i64, 366), b - a);
}

/// Reads all remaining bytes from an already-open file into a fresh allocation.
/// Replaces 0.15's `File.readToEndAlloc`, which was removed in 0.16.
pub fn readAllAlloc(io: std.Io, file: std.Io.File, alloc: Allocator, limit: usize) ![]u8 {
    var buf: [4096]u8 = undefined;
    var fr = file.reader(io, &buf);
    return fr.interface.allocRemaining(alloc, .limited(limit));
}

test "version ordering: later semver string sorts higher" {
    try tst.expect(std.mem.order(u8, "2023-01-01", "2022-01-01") == .gt);
    try tst.expect(std.mem.order(u8, "2022-01-01", "2023-01-01") == .lt);
}

test "replace_org replaces organization shortcode" {
    const allocator = tst.allocator;

    var arr = Array(u8).empty;
    defer arr.deinit(allocator);
    try arr.appendSlice(allocator, "Welcome to {{ org() }}!");

    try replace_org(allocator, &arr, "AcmeCorp");

    try tst.expectEqualStrings("Welcome to AcmeCorp!", arr.items);
}

test "replace_mermaid replaces mermaid shortcode with code block" {
    const allocator = tst.allocator;

    var arr = Array(u8).empty;
    defer arr.deinit(allocator);
    try arr.appendSlice(allocator,
        \\Some text
        \\{% mermaid() %}
        \\graph TD;
        \\A-->B;
        \\{% end %}
        \\End text
    );

    try replace_mermaid(allocator, &arr);

    const expected =
        \\Some text
        \\~~~mermaid
        \\graph TD;
        \\A-->B;
        \\~~~
        \\End text
    ;
    try tst.expectEqualStrings(expected, arr.items);
}

pub const DummyProgress = struct {
    pub fn start(_: DummyProgress, _: []const u8, _: usize) DummyProgress {
        return DummyProgress{};
    }
    pub fn end(_: DummyProgress) void {}
    pub fn setEstimatedTotalItems(_: DummyProgress, _: usize) void {}
    pub fn completeOne(_: DummyProgress) void {}
};

test "FM parse via zigmark reads title from example policy" {
    const alloc = tst.allocator;
    var f = std.fs.cwd().openFile(
        "content/policies/example-security-policy.md",
        .{ .mode = .read_only },
    ) catch return; // skip if file absent in test environment
    defer f.close();

    const contents = try f.readToEndAlloc(alloc, max_policy_bytes);
    defer alloc.free(contents);

    var fm = try zigmark.Frontmatter.initFromMarkdown(alloc, contents);
    defer fm.deinit();
    try tst.expect(fm.get("title") != null);
}

/// The UTF-8 solid-block character `█` (U+2588) used to mask redacted spans.
const redaction_block = "█";

/// Build the replacement string for a redacted span: `count` solid `█` blocks
/// with a break space inserted after every 10 so Typst can wrap the bar within
/// the text width (a redacted block otherwise becomes one unbreakable "word",
/// since redaction also replaces the block's internal spaces and newlines).
/// Caller owns the returned slice.
fn buildRedactionBar(a: Allocator, count: usize) ![]u8 {
    var buf = Array(u8).empty;
    errdefer buf.deinit(a);
    var n: usize = 0;
    while (n < count) : (n += 1) {
        try buf.appendSlice(a, redaction_block);
        if ((n + 1) % 10 == 0) try buf.append(a, ' ');
    }
    return buf.toOwnedSlice(a);
}

/// Redact `{% redact() %}...{% end %}` shortcode blocks in `txt`.
///
/// When `remove` is true the entire block (tags and content) is replaced with
/// solid `█` bars; when false the tags are stripped and the inner content is
/// kept. Whitespace-trim tag variants (`{%- redact() -%}`, `{%- end -%}`) are
/// accepted so trimmed authoring never leaks a block past the redactor. Any
/// orphaned tag with no matching pair is a hard error (`UnclosedRedaction`) so
/// a malformed block can never pass through silently into a `--redact` PDF.
///
/// Redacted spans are masked with `█` directly rather than an underscore
/// placeholder: underscores collide with legitimate content (snake_case
/// identifiers, `_emphasis_`, URLs) and previously corrupted every literal
/// underscore in the document when converted to bars in a second pass.
pub fn redact(a: Allocator, txt: *Array(u8), remove: bool) !void {
    const r: mvzr.Regex = mvzr.compile("\\{%-?\\s*redact\\(\\)\\s*-?%\\}.+?\\{%-?\\s*end\\s*-?%\\}").?;
    const unclosed = mvzr.compile("\\{%-?\\s*(redact\\(\\)|end)\\s*-?%\\}").?;

    if (!r.isMatch(txt.items)) {
        // No complete pair — fail loudly if any orphaned tag is present.
        if (unclosed.isMatch(txt.items)) return error.UnclosedRedaction;
        return;
    }

    var new = try txt.clone(a);

    var iter = r.iterator(txt.items);
    while (iter.next()) |m| {
        const s = std.mem.indexOf(u8, m.slice, "%}") orelse return error.InvalidShortCode;
        const e = std.mem.lastIndexOf(u8, m.slice, "{%") orelse return error.InvalidShortCode;
        const inner = m.slice[s + 2 .. e - 1];
        const replace = if (remove)
            try buildRedactionBar(a, m.slice.len)
        else blk: {
            const replace = try a.alloc(u8, m.slice.len);
            @memset(replace, ' ');
            @memcpy(replace[0..inner.len], inner);
            break :blk replace;
        };
        defer a.free(replace);

        try new.replaceRange(a, m.start, m.slice.len, replace);
        iter = r.iterator(new.items);
    }
    txt.deinit(a);
    txt.* = new;

    // After processing all matched pairs, any remaining tag is an orphan.
    if (unclosed.isMatch(txt.items)) return error.UnclosedRedaction;
}

/// Returns true when `name` resolves to an executable on the PATH.
pub fn executableInPath(io: std.Io, env: *std.process.Environ.Map, name: []const u8) bool {
    if (comptime builtin.os.tag == .windows) return false;
    const path_env = env.get("PATH") orelse return false;
    var it = std.mem.tokenizeScalar(u8, path_env, ':');
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    while (it.next()) |dir| {
        const full = std.fmt.bufPrint(&buf, "{s}/{s}", .{ dir, name }) catch continue;
        std.Io.Dir.accessAbsolute(io, full, .{}) catch continue;
        return true;
    }
    return false;
}

// ============================================================
// Stamp-file caching helpers
// ============================================================

/// Derive a stamp filename that is unique to the policy's full relative path,
/// not just its basename. Two policies with the same file name in different
/// directories (`access/policy.md` vs `data/policy.md`) must not share a stamp,
/// or the second would be skipped as "up to date" and its PDF never produced.
/// Path separators become `_`; the trailing `.md` is dropped so the stamp does
/// not look like a Markdown file. The result is a single flat filename.
pub fn stampName(alloc: Allocator, input_path: []const u8) ![]u8 {
    var rel = std.mem.trimStart(u8, input_path, "/\\");
    if (std.mem.endsWith(u8, rel, ".md")) rel = rel[0 .. rel.len - 3];
    const key = try alloc.dupe(u8, rel);
    for (key) |*c| {
        if (c.* == '/' or c.* == '\\') c.* = '_';
    }
    return key;
}

/// Returns true if the per-policy stamp file is newer than the source file,
/// meaning the PDF is already up to date and compilation can be skipped.
/// Returns false on any IO error so the policy is always rebuilt on doubt.
pub fn stampIsNewer(io: std.Io, input_path: []const u8, stamps_dir: []const u8, alloc: Allocator) bool {
    const name = stampName(alloc, input_path) catch return false;
    defer alloc.free(name);
    const stamp_path = std.fs.path.join(alloc, &.{ stamps_dir, name }) catch return false;
    defer alloc.free(stamp_path);

    const src = std.Io.Dir.openFileAbsolute(io, input_path, .{}) catch return false;
    defer src.close(io);
    const src_stat = src.stat(io) catch return false;

    const stamp = std.Io.Dir.cwd().openFile(io, stamp_path, .{}) catch return false;
    defer stamp.close(io);
    const stamp_stat = stamp.stat(io) catch return false;

    return src_stat.mtime.nanoseconds < stamp_stat.mtime.nanoseconds;
}

/// Touches a stamp file for `input_path` inside `stamps_dir` to record that
/// compilation succeeded. Failures are non-fatal (worst case: needless rebuild).
pub fn writeStamp(io: std.Io, alloc: Allocator, stamps_dir: []const u8, input_path: []const u8) void {
    const name = stampName(alloc, input_path) catch return;
    defer alloc.free(name);
    const stamp_path = std.fs.path.join(alloc, &.{ stamps_dir, name }) catch return;
    defer alloc.free(stamp_path);
    const f = std.Io.Dir.cwd().createFile(io, stamp_path, .{ .truncate = true }) catch return;
    f.close(io);
}

/// Returns true when the policy at `dir`/`sub_path` is marked `draft: true` in
/// its front matter. Draft policies are excluded from PDF generation (Zola
/// likewise omits them from the site), so an unapproved draft never ships an
/// official-looking PDF at a guessable URL. Returns false on any read/parse
/// error so a policy is never silently dropped by mistake — a malformed file
/// surfaces later as a real compile error instead.
pub fn isDraftPolicy(io: std.Io, alloc: Allocator, dir: std.Io.Dir, sub_path: []const u8) bool {
    const content = dir.readFileAlloc(io, sub_path, alloc, .limited(10 * 1024 * 1024)) catch return false;
    defer alloc.free(content);
    var fm = zigmark.Frontmatter.initFromMarkdown(alloc, content) catch return false;
    defer fm.deinit();
    return switch (fm.get("draft") orelse return false) {
        .bool => |b| b,
        .string => |s| std.ascii.eqlIgnoreCase(s, "true"),
        else => false,
    };
}

/// Converts {% admonition(type="...", title="...") %}...{% end %} shortcodes
/// to pandoc blockquotes before the markdown reaches pandoc.
/// Each type maps to a Unicode prefix so the callout is visually distinct in
/// the rendered PDF without requiring a custom LaTeX filter.
pub fn replace_admonitions(alloc: Allocator, txt: *Array(u8)) !void {
    const re: mvzr.Regex = mvzr.compile("\\{%\\s*admonition\\([^)]*\\)\\s*%\\}.+?\\{%\\s*end\\s*%\\}").?;
    if (!re.isMatch(txt.items)) return;

    var new = try txt.clone(alloc);

    var iter = re.iterator(txt.items);
    while (iter.next()) |m| {
        // Locate the end of the opening tag and start of the closing tag.
        const tag_end = std.mem.indexOf(u8, m.slice, "%}") orelse return error.InvalidShortCode;
        const close_start = std.mem.lastIndexOf(u8, m.slice, "{%") orelse return error.InvalidShortCode;

        // Extract the parameter string between the outer parentheses.
        const open_tag = m.slice[0 .. tag_end + 2];
        const paren_open = std.mem.indexOf(u8, open_tag, "(") orelse return error.InvalidShortCode;
        const paren_close = std.mem.lastIndexOf(u8, open_tag, ")") orelse return error.InvalidShortCode;
        const params = open_tag[paren_open + 1 .. paren_close];

        // Parse type="..." (default: "note").
        const adm_type: []const u8 = if (std.mem.indexOf(u8, params, "type=\"")) |ti| blk: {
            const start = ti + 6;
            const end = std.mem.indexOfPos(u8, params, start, "\"") orelse break :blk "note";
            break :blk params[start..end];
        } else "note";

        // Parse optional title="...".
        const custom_title: ?[]const u8 = if (std.mem.indexOf(u8, params, "title=\"")) |ti| blk: {
            const start = ti + 7;
            const end = std.mem.indexOfPos(u8, params, start, "\"") orelse break :blk null;
            break :blk params[start..end];
        } else null;

        // Plain ASCII labels - font-agnostic, works with any LaTeX setup.
        const prefix: []const u8 =
            if (std.mem.eql(u8, adm_type, "warning")) "WARNING" else if (std.mem.eql(u8, adm_type, "danger")) "DANGER" else if (std.mem.eql(u8, adm_type, "tip")) "TIP" else if (std.mem.eql(u8, adm_type, "important")) "IMPORTANT" else "NOTE";

        const heading = if (custom_title) |ct|
            try std.fmt.allocPrint(alloc, "{s}: {s}", .{ prefix, ct })
        else
            try alloc.dupe(u8, prefix);
        defer alloc.free(heading);

        // Body is everything between the opening %} and the closing {%.
        const body_raw = std.mem.trim(u8, m.slice[tag_end + 2 .. close_start], " \n\r");

        // Build a pandoc blockquote: "> **heading**\n>\n> line\n> ..."
        var blockquote = Array(u8).empty;
        defer blockquote.deinit(alloc);

        try blockquote.appendSlice(alloc, "> **");
        try blockquote.appendSlice(alloc, heading);
        try blockquote.appendSlice(alloc, "**\n>\n");

        var lines = std.mem.splitScalar(u8, body_raw, '\n');
        while (lines.next()) |line| {
            try blockquote.appendSlice(alloc, "> ");
            try blockquote.appendSlice(alloc, std.mem.trimEnd(u8, line, " \r"));
            try blockquote.append(alloc, '\n');
        }

        try new.replaceRange(alloc, m.start, m.slice.len, blockquote.items);
        iter = re.iterator(new.items);
    }
    txt.deinit(alloc);
    txt.* = new;
}

test "Admonition replacement" {
    const input =
        \\{% admonition(type="warning") %}
        \\Access will be suspended after 30 days.
        \\{% end %}
    ;
    var buf = Array(u8).empty;
    defer buf.deinit(tst.allocator);
    try buf.appendSlice(tst.allocator, input);
    try replace_admonitions(tst.allocator, &buf);

    try tst.expect(std.mem.indexOf(u8, buf.items, "> **") != null);
    try tst.expect(std.mem.indexOf(u8, buf.items, "WARNING") != null);
    try tst.expect(std.mem.indexOf(u8, buf.items, "Access will be suspended") != null);
    // Shortcode tags must be gone.
    try tst.expect(std.mem.indexOf(u8, buf.items, "{%") == null);

    // Custom title variant.
    const input2 =
        \\{% admonition(type="important", title="Legal Hold") %}
        \\Do not delete any records.
        \\{% end %}
    ;
    var buf2 = Array(u8).empty;
    defer buf2.deinit(tst.allocator);
    try buf2.appendSlice(tst.allocator, input2);
    try replace_admonitions(tst.allocator, &buf2);

    try tst.expect(std.mem.indexOf(u8, buf2.items, "IMPORTANT") != null);
    try tst.expect(std.mem.indexOf(u8, buf2.items, "Legal Hold") != null);
}

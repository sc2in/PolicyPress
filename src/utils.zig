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
    /// Generates a PDF filename from the title and most recent version in the front matter.
    pub fn filename(self: FrontMatter, a: Allocator) ![]u8 {
        const tmp = self.title;
        std.mem.replaceScalar(u8, tmp, ' ', '_');
        return std.fmt.allocPrint(a, "{s}_-_v{s}.pdf", .{ tmp, self.most_recent_version });
    }

    pub fn deinit(self: *FrontMatter, a: Allocator) void {
        a.free(self.title);
        a.free(self.last_reviewed);
        a.free(self.most_recent_version);
    }
};

/// Parses front matter from a markdown file using zigmark, extracts document
/// metadata, and returns a FrontMatter struct.  Handles YAML, TOML, JSON, and
/// ZON front matter; resolves empty arrays without errors (fixes #73).
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

    // Find the most recent revision by comparing version strings.
    var most_recent = revisions[0];
    for (revisions[1..]) |rev| {
        const cur_obj = switch (most_recent) {
            .object => |o| o,
            else => continue,
        };
        const new_obj = switch (rev) {
            .object => |o| o,
            else => continue,
        };
        const cur_ver = switch (cur_obj.get("version") orelse continue) {
            .string => |s| s,
            else => continue,
        };
        const new_ver = switch (new_obj.get("version") orelse continue) {
            .string => |s| s,
            else => continue,
        };
        if (std.mem.order(u8, new_ver, cur_ver) == .gt) {
            most_recent = rev;
        }
    }

    const most_recent_obj = switch (most_recent) {
        .object => |o| o,
        else => return error.InvalidRevisionFormat,
    };
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
};

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

    const contents = try f.readToEndAlloc(alloc, 100_000_000);
    defer alloc.free(contents);

    var fm = try zigmark.Frontmatter.initFromMarkdown(alloc, contents);
    defer fm.deinit();
    try tst.expect(fm.get("title") != null);
}

pub fn redact(a: Allocator, txt: *Array(u8), remove: bool) !void {
    const r: mvzr.Regex = mvzr.compile("\\{%\\s*redact\\(\\)\\s*%\\}.+?\\{%\\s*end\\s*%\\}").?;
    if (!r.isMatch(txt.items)) return;

    var new = try txt.clone(a);

    var iter = r.iterator(txt.items);
    while (iter.next()) |m| {
        const s = std.mem.indexOf(u8, m.slice, "%}") orelse return error.InvalidShortCode;
        const e = std.mem.lastIndexOf(u8, m.slice, "{%") orelse return error.InvalidShortCode;
        const inner = m.slice[s + 2 .. e - 1];
        const replace = if (remove) blk: {
            const replace = try a.alloc(u8, m.slice.len);
            @memset(replace, '_');
            break :blk replace;
        } else blk: {
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
}

/// Replace `_` characters in the **body** of `txt` (after the frontmatter) with
/// the UTF-8 solid-block character `█` (U+2588).
///
/// `redact` fills redacted spans with underscores.  In CommonMark, a run of
/// three or more `_` on its own line is a thematic break, so zigmark renders it
/// as a thin gray rule.  Replacing with `█` produces proper black-bar redaction
/// marks without any special Markdown meaning.
///
/// Only the body is processed; the frontmatter block (keys like `last_reviewed`,
/// `major_revisions`) must remain intact for the later metadata extraction pass.
pub fn underscoresToBlocks(alloc: Allocator, txt: *Array(u8)) !void {
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
    // width (redact replaces spaces too, producing one unbreakable "word").
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

test "underscoresToBlocks replaces body underscores with solid blocks" {
    const allocator = tst.allocator;
    var arr = Array(u8).empty;
    defer arr.deinit(allocator);
    try arr.appendSlice(allocator, "some ____ text");

    try underscoresToBlocks(allocator, &arr);
    try tst.expectEqualStrings("some ████ text", arr.items);
}

test "underscoresToBlocks leaves frontmatter untouched" {
    const allocator = tst.allocator;
    var arr = Array(u8).empty;
    defer arr.deinit(allocator);
    try arr.appendSlice(allocator, "---\nlast_reviewed: 2026-01-01\n---\nbody __ here");

    try underscoresToBlocks(allocator, &arr);
    try tst.expectEqualStrings("---\nlast_reviewed: 2026-01-01\n---\nbody ██ here", arr.items);
}

test "underscoresToBlocks inserts a break space every 10 blocks" {
    const allocator = tst.allocator;
    var arr = Array(u8).empty;
    defer arr.deinit(allocator);
    try arr.appendSlice(allocator, "_" ** 12);

    try underscoresToBlocks(allocator, &arr);
    try tst.expectEqualStrings("██████████ ██", arr.items);
}

test "underscoresToBlocks is a no-op without underscores" {
    const allocator = tst.allocator;
    var arr = Array(u8).empty;
    defer arr.deinit(allocator);
    try arr.appendSlice(allocator, "clean text");

    try underscoresToBlocks(allocator, &arr);
    try tst.expectEqualStrings("clean text", arr.items);
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

test "Redaction" {
    const t =
        \\{% redact() %}
        \\This is a test policy for demonstration purposes. It contains sensitive information that should not be disclosed.
        \\{% end %}
    ;
    var ts = Array(u8).empty;
    defer ts.deinit(tst.allocator);

    const expected = [_]u8{'_'} ** t.len;

    try ts.appendSlice(tst.allocator, t);
    try redact(tst.allocator, &ts, true);
    // std.debug.print("{s}\n", .{ts.items});
    try tst.expectEqualStrings(&expected, ts.items);

    var t2 = Array(u8).empty;
    defer t2.deinit(tst.allocator);

    const expected2 = "This is a test policy for demonstration purposes. It contains sensitive information that should not be disclosed.";

    try t2.appendSlice(tst.allocator, t);
    try redact(tst.allocator, &t2, false);
    try tst.expectEqualStrings(std.mem.trim(u8, expected2, "\n "), std.mem.trim(u8, t2.items, "\n "));
}

// ============================================================
// Stamp-file caching helpers
// ============================================================

/// Returns true if the per-policy stamp file is newer than the source file,
/// meaning the PDF is already up to date and compilation can be skipped.
/// Returns false on any IO error so the policy is always rebuilt on doubt.
pub fn stampIsNewer(io: std.Io, input_path: []const u8, stamps_dir: []const u8, alloc: Allocator) bool {
    const stem = std.fs.path.stem(std.fs.path.basename(input_path));
    const stamp_path = std.fs.path.join(alloc, &.{ stamps_dir, stem }) catch return false;
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
    const stem = std.fs.path.stem(std.fs.path.basename(input_path));
    const stamp_path = std.fs.path.join(alloc, &.{ stamps_dir, stem }) catch return;
    defer alloc.free(stamp_path);
    const f = std.Io.Dir.cwd().createFile(io, stamp_path, .{ .truncate = true }) catch return;
    f.close(io);
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

//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: AGPL-3.0-or-later
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
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
    pub fn format(self: FrontMatter, comptime _: []const u8, _: anytype, writer: anytype) !void {
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

    var arr = Array(u8){};
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

/// Recursively finds and opens all markdown files in the specified policy directory, returning them as an array of files.
pub fn find_md_files(a: Allocator, root: std.fs.Dir, policy_dir: []const u8) ![]MDFile {
    panlog.debug("Reading in policies from: {s}\n", .{policy_dir});
    var files = Array(MDFile).init(a);
    defer files.deinit();

    const dir = std.fs.path.dirname(policy_dir) orelse return error.InvalidPolicyRoot;
    var policy_root = try (try root.openDir("content", .{
        .access_sub_paths = true,
        .iterate = true,
    })).openDir(dir, .{
        .access_sub_paths = true,
        .iterate = true,
    });
    defer policy_root.close();

    try find_inner(&files, policy_root);
    return try files.toOwnedSlice();
}
/// Helper function to recursively traverse directories and append markdown files to the provided array.
pub fn find_inner(files: *Array(MDFile), start: std.fs.Dir) !void {
    var num: usize = 0;
    var iter = start.iterate();
    while (try iter.next()) |_| {
        num += 1;
    }

    iter.reset();
    while (try iter.next()) |entry| {
        switch (entry.kind) {
            .file => {
                if (!std.mem.startsWith(u8, entry.name, "_") and
                    std.mem.endsWith(u8, entry.name, ".md"))
                    try files.append(.{
                        .path = try start.realpathAlloc(files.allocator, entry.name),
                    });
            },
            .directory => {
                var sub = try start.openDir(entry.name, .{ .access_sub_paths = true, .iterate = true });
                defer sub.close();
                try find_inner(files, sub);
            },
            else => {},
        }
    }
}

/// Runs an external command to extract the dominant color from the logo image and returns it as a string.
pub fn get_logo_color(a: Allocator, path: []const u8) ![]u8 {
    const argv = [_][]const u8{
        "magick",
        path,
        "-scale",
        "1x1\\!",
        "-format",
        "'%[hex:u]'",
        "info:",
    };
    var child = std.process.Child.init(&argv, a);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    var out: std.ArrayListUnmanaged(u8) = .empty;
    var err: std.ArrayListUnmanaged(u8) = .empty;
    defer {
        out.deinit(a);
        err.deinit(a);
    }
    try child.spawn();
    try child.collectOutput(a, &out, &err, 100_000);

    const exit_code = try child.wait();
    panlog.debug("{any} {s}\n", .{ exit_code, out.items });
    panlog.debug("{any} {s}\n", .{ exit_code, err.items });
    return try out.toOwnedSlice(a);
}

test "version ordering: later semver string sorts higher" {
    try tst.expect(std.mem.order(u8, "2023-01-01", "2022-01-01") == .gt);
    try tst.expect(std.mem.order(u8, "2022-01-01", "2023-01-01") == .lt);
}

test "replace_org replaces organization shortcode" {
    const allocator = tst.allocator;

    var arr = Array(u8){};
    defer arr.deinit(allocator);
    try arr.appendSlice(allocator, "Welcome to {{ org() }}!");

    try replace_org(allocator, &arr, "AcmeCorp");

    try tst.expectEqualStrings("Welcome to AcmeCorp!", arr.items);
}

test "replace_mermaid replaces mermaid shortcode with code block" {
    const allocator = tst.allocator;

    var arr = Array(u8){};
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

test "Redaction" {
    const t =
        \\{% redact() %}
        \\This is a test policy for demonstration purposes. It contains sensitive information that should not be disclosed.
        \\{% end %}
    ;
    var ts = Array(u8){};
    defer ts.deinit(tst.allocator);

    const expected = [_]u8{'_'} ** t.len;

    try ts.appendSlice(tst.allocator, t);
    try redact(tst.allocator, &ts, true);
    // std.debug.print("{s}\n", .{ts.items});
    try tst.expectEqualStrings(&expected, ts.items);

    var t2 = Array(u8){};
    defer t2.deinit(tst.allocator);

    const expected2 = "This is a test policy for demonstration purposes. It contains sensitive information that should not be disclosed.";

    try t2.appendSlice(tst.allocator, t);
    try redact(tst.allocator, &t2, false);
    try tst.expectEqualStrings(std.mem.trim(u8, expected2, "\n "), std.mem.trim(u8, t2.items, "\n "));
}

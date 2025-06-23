const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const Yaml = @import("yaml").Yaml;
const mvzr = @import("mvzr");
const tomlz = @import("tomlz");
const ffm = @import("frontmatter.zig");

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
        return std.fmt.allocPrint(a, "{s}/{s}_-_v{s}.pdf", .{ "", self.title, self.most_recent_version });
    }

    pub fn deinit(self: *FrontMatter, a: Allocator) void {
        a.free(self.title);
        a.free(self.last_reviewed);
        a.free(self.most_recent_version);
    }
};

/// Parses YAML front matter from a markdown file, extracts document metadata, formats the title, and returns a FrontMatter struct.
pub fn get_metadata(a: Allocator, txt: *Array(u8), config: anytype) !FrontMatter {
    const end_fm = std.mem.indexOfPos(u8, txt.items, 3, "---") orelse return error.InvalidFrontMatter;
    var y: Yaml = .{ .source = txt.items[3..end_fm] };
    defer y.deinit(a);

    y.load(a) catch |err| switch (err) {
        error.ParseFailure => {
            std.debug.assert(y.parse_errors.errorMessageCount() > 0);
            // y.parse_errors.renderToStdErr(.{ .ttyconf = std.io.tty.detectConfig(std.io.getStdErr()) });
            return error.ParseFailure;
        },
        else => return err,
    };
    const map = y.docs.items[0].map;
    panlog.debug("Procesing: {s}\n", .{map.get("title").?.string});
    const extra = map.get("extra").?.map;
    const major_revisions = extra.get("major_revisions").?.list;
    std.mem.sort(
        Yaml.Value,
        major_revisions,
        .{},
        revisions_lt,
    );

    const most_recent = major_revisions[0];
    const m = try most_recent.asMap();

    const rd = "{s} (Redacted) (Draft)";
    const r = "{s} (Redacted)";
    const d = "{s} (Draft)";
    const e = "{s}";
    const t = map.get("title").?.string;
    const title = if (config.redact and config.is_draft)
        try std.fmt.allocPrint(a, rd, .{t})
    else if (config.redact)
        try std.fmt.allocPrint(a, r, .{t})
    else if (config.is_draft)
        try std.fmt.allocPrint(a, d, .{t})
    else
        try std.fmt.allocPrint(a, e, .{t});
    return .{
        .title = title,
        .last_reviewed = try a.dupe(u8, extra.get("last_reviewed").?.string),
        .most_recent_version = switch (m.get("version").?) {
            .string => |s| try a.dupe(u8, s),
            .float => |f| try std.fmt.allocPrint(a, "{d:0.1}", .{f}),
            else => return error.InvalidVersionType,
        },
    };
}

/// Comparator function for sorting YAML revision values in ascending order.
pub fn revisions_lt(_: @TypeOf(.{}), a: Yaml.Value, b: Yaml.Value) bool {
    const as = a.string;
    const bs = b.string;

    for (as, 0..) |ac, i| {
        if (ac < bs[i]) return true;
    }
    return false;
}

/// Replaces all instances of the organization placeholder in the markdown text with the actual organization name from the global configuration.
pub fn replace_org(txt: *Array(u8), with: []const u8) !void {
    const orgsc: mvzr.Regex = mvzr.compile("\\{\\{\\s*org\\(\\)\\s*\\}\\}").?;

    if (!orgsc.isMatch(txt.items)) return;

    var new = try txt.clone();

    var iter = orgsc.iterator(txt.items);
    while (iter.next()) |match| {
        try new.replaceRange(match.start, match.slice.len, with);
        iter = orgsc.iterator(new.items);
    }
    txt.deinit();
    txt.* = new;
}

/// Replaces all instances of the [...](@/...) links inthe markdown text with the path relative to content
pub fn replace_zola_at(txt: *Array(u8)) !void {
    const at: mvzr.Regex = mvzr.compile("\\]\\(@/").?;

    if (!at.isMatch(txt.items)) return;

    var new = try txt.clone();

    var iter = at.iterator(txt.items);
    while (iter.next()) |match| {
        try new.replaceRange(match.start, match.slice.len, "](content/");
        iter = at.iterator(new.items);
    }
    txt.deinit();
    txt.* = new;
}

test "replace_zola_at" {
    const allocator = tst.allocator;

    var arr = Array(u8).init(allocator);
    defer arr.deinit();
    try arr.appendSlice(
        \\[some link](@/policies/privacy)
    );

    try replace_zola_at(&arr);

    const expected =
        \\[some link](content/policies/privacy)
    ;
    try tst.expectEqualStrings(expected, arr.items);
}

/// Finds and replaces custom Mermaid code blocks in the markdown with a standardized code block format.
pub fn replace_mermaid(txt: *Array(u8)) !void {
    const mermaid: mvzr.Regex = mvzr.compile("\\{%\\s*mermaid\\(\\)\\s*%\\}.+?\\{%\\s*end\\s*%\\}").?;
    if (!mermaid.isMatch(txt.items)) return;

    var new = try txt.clone();

    var iter = mermaid.iterator(txt.items);
    while (iter.next()) |m| {
        const s = std.mem.indexOf(u8, m.slice, "%}") orelse return error.InvalidShortCode;
        const e = std.mem.lastIndexOf(u8, m.slice, "{%") orelse return error.InvalidShortCode;
        const inner = m.slice[s + 2 .. e - 1];
        const replace = try std.fmt.allocPrint(txt.allocator, "~~~mermaid{s}\n~~~", .{inner});
        defer txt.allocator.free(replace);

        try new.replaceRange(m.start, m.slice.len, replace);
        iter = mermaid.iterator(new.items);
    }
    txt.deinit();
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

test "revisions_lt sorts revisions lexically" {
    // Simulate two YAML values
    const a = Yaml.Value{ .string = "2022-01-01" };
    const b = Yaml.Value{ .string = "2023-01-01" };
    try tst.expect(revisions_lt(.{}, a, b));
    try tst.expect(!revisions_lt(.{}, b, a));
}

test "replace_org replaces organization shortcode" {
    const allocator = tst.allocator;

    var arr = Array(u8).init(allocator);
    defer arr.deinit();
    try arr.appendSlice("Welcome to {{ org() }}!");

    try replace_org(&arr, "AcmeCorp");

    try tst.expectEqualStrings("Welcome to AcmeCorp!", arr.items);
}

test "replace_mermaid replaces mermaid shortcode with code block" {
    const allocator = tst.allocator;

    var arr = Array(u8).init(allocator);
    defer arr.deinit();
    try arr.appendSlice(
        \\Some text
        \\{% mermaid() %}
        \\graph TD;
        \\A-->B;
        \\{% end %}
        \\End text
    );

    try replace_mermaid(&arr);

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

test {
    const alloc = tst.allocator;
    var f = try std.fs.cwd().openFile(
        "content/policies/aeip.md",
        .{ .mode = .read_only },
    );
    defer f.close();

    const contents = try f.readToEndAlloc(alloc, 100_000_000);
    defer alloc.free(contents);
    var fm = try FM.parse(alloc, contents);
    defer fm.deinit();

    // std.debug.print("{s}\n", .{(try fm.get("title")).?.string});
}
test {
    _ = ffm;
}

pub const FM = struct {
    contents: union(enum) {
        toml: tomlz.Table,
        yaml: Yaml,
        ziggy: struct {},
    },
    raw: []u8,
    alloc: Allocator,
    pub fn deinit(self: *FM) void {
        switch (self.contents) {
            .toml => |*t| t.deinit(self.alloc),
            .yaml => |*y| y.deinit(self.alloc),
            else => unreachable,
        }
        self.alloc.free(self.raw);
    }
    const NeededValues = struct {
        title: []const u8,
    };
    pub fn parse(a: Allocator, txt: []const u8) !FM {
        var fm: FM = undefined;
        fm.alloc = a;

        switch (txt[0]) {
            '-' => //Yaml
            {
                const end_fm = std.mem.indexOfPos(u8, txt, 3, "---") orelse return error.InvalidFrontMatter;
                fm.raw = try a.alloc(u8, end_fm - 3);
                std.mem.copyForwards(u8, fm.raw, txt[3..end_fm]);

                var y: Yaml = .{ .source = fm.raw };

                y.load(a) catch |err| switch (err) {
                    error.ParseFailure => {
                        std.debug.assert(y.parse_errors.errorMessageCount() > 0);
                        // y.parse_errors.renderToStdErr(.{ .ttyconf = std.io.tty.detectConfig(std.io.getStdErr()) });
                        return error.ParseFailure;
                    },
                    else => return err,
                };
                fm.contents = .{ .yaml = y };
            },
            '+' => //toml
            {
                const end_fm = std.mem.indexOfPos(u8, txt, 3, "+++") orelse return error.InvalidFrontMatter;
                fm.raw = try a.alloc(u8, end_fm - 3);
                std.mem.copyForwards(u8, fm.raw, txt[3..end_fm]);
                const t = try tomlz.parse(a, fm.raw);
                fm.contents = .{ .toml = t };
            },
            '.' => //ziggy
            return error.Unimplemented,
            else => return error.NoFrontmatterFound,
        }
        return fm;
    }

    pub fn get(self: FM, key: []const u8) !?Yaml.Value {
        return switch (self.contents) {
            .yaml => |y| y.docs.items[0].map.get(key),
            // .toml => |t| return Yaml.Value{ .map = (t.getTable(key) orelse return null).table },
            else => error.Unimplemented,
        };
    }
};

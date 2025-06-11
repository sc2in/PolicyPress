const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const tomlz = @import("tomlz");
const Yaml = @import("yaml").Yaml;
const ctime = @cImport(@cInclude("time.h"));
const mvzr = @import("mvzr");
var alloc: Allocator = undefined;
var org: []const u8 = undefined;

pub const std_options: std.Options = .{
    .log_level = .info,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .parser, .level = .debug },
        .{ .scope = .pandoc, .level = .debug },
    },
    .logFn = logFn,
};
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

const panlog = std.log.scoped(.pandoc);

pub fn main() !void {
    panlog.info("Hello from my_scope\n", .{});
    panlog.info("Hello from default scope\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    alloc = gpa.allocator();

    var dt_str_buf: [40]u8 = undefined;
    const t = ctime.time(null);
    const lt = ctime.localtime(&t);
    const format = "%Y";
    const dt_str_len = ctime.strftime(&dt_str_buf, dt_str_buf.len, format, lt);
    const current_year = dt_str_buf[0..dt_str_len];
    _ = current_year;

    const argv = [_][]const u8{ "echo", "Hello", "World" };
    var child = std.process.Child.init(&argv, alloc);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    var out: std.ArrayListUnmanaged(u8) = .empty;
    var err: std.ArrayListUnmanaged(u8) = .empty;
    defer {
        out.deinit(alloc);
        err.deinit(alloc);
    }
    try child.spawn();
    try child.collectOutput(alloc, &out, &err, 100_000);

    const exit_code = try child.wait();
    panlog.debug("{any} {s}\n", .{ exit_code, out.items });
    var workDir = try std.fs.openDirAbsolute(
        std.posix.getenv("DEVBOX_PROJECT_ROOT") orelse return error.ProjectRootNotFoundInEnv,
        .{
            .access_sub_paths = true,
            .iterate = true,
        },
    );
    defer workDir.close();
    var conf_file = try workDir.openFile("config.toml", .{ .mode = .read_only });
    defer conf_file.close();

    const config_contents = try conf_file.readToEndAlloc(alloc, 100_000_000);
    defer alloc.free(config_contents);

    var config = try tomlz.parse(alloc, config_contents);
    defer config.deinit(alloc);

    const extra = config.getTable("extra") orelse return error.NoExtraInConfig;
    org = extra.getString("organization") orelse return error.NoOrganizationInExtra;
    const policy_root = extra.getString("policy_root") orelse return error.NoPolicyRootInExtra;
    // const redact = b.option(bool, "redact", "Redact PDFs") orelse false;
    // const draft = b.option(bool, "redact", "Redact PDFs") orelse false;

    const md_files = try find_md_files(workDir, policy_root);
    defer {
        for (md_files) |f|
            f.close();
        alloc.free(md_files);
    }
    const total_files = md_files.len;
    std.debug.print("Building PDFs from {} markdown files in {s} .. \n", .{ total_files, policy_root });
    for (md_files) |file| {
        try process_md_file(file);
    }
}

fn get_metadata(txt: *Array(u8)) !FrontMatter {
    const end_fm = std.mem.indexOfPos(u8, txt.items, 3, "---") orelse return error.InvalidFrontMatter;
    var y: Yaml = .{ .source = txt.items[3..end_fm] };
    defer y.deinit(alloc);

    y.load(alloc) catch |err| switch (err) {
        error.ParseFailure => {
            std.debug.assert(y.parse_errors.errorMessageCount() > 0);
            // y.parse_errors.renderToStdErr(.{ .ttyconf = std.io.tty.detectConfig(std.io.getStdErr()) });
            return error.ParseFailure;
        },
        else => return err,
    };
    const map = y.docs.items[0].map;
    panlog.info("Procesing: {s}\n", .{map.get("title").?.string});
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
    return .{
        .title = try alloc.dupe(u8, map.get("title").?.string),
        .last_reviewed = try alloc.dupe(u8, extra.get("last_reviewed").?.string),
        .most_recent_version = switch (m.get("version").?) {
            .string => |s| try alloc.dupe(u8, s),
            .float => |f| try std.fmt.allocPrint(alloc, "{d:0.1}", .{f}),
            else => return error.InvalidVersionType,
        },
    };
}
const FrontMatter = struct {
    title: []u8,
    most_recent_version: []u8,
    last_reviewed: []u8,

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

    pub fn deinit(self: *FrontMatter) void {
        alloc.free(self.title);
        alloc.free(self.last_reviewed);
        alloc.free(self.most_recent_version);
    }
};

fn revisions_lt(_: @TypeOf(.{}), a: Yaml.Value, b: Yaml.Value) bool {
    const as = a.string;
    const bs = b.string;

    for (as, 0..) |ac, i| {
        if (ac < bs[i]) return true;
    }
    return false;
}

fn process_md_file(md: std.fs.File) !void {
    const raw = try md.readToEndAlloc(alloc, 100_000_000);
    var contents = Array(u8){
        .items = raw,
        .allocator = alloc,
        .capacity = raw.len,
    };
    defer contents.deinit();

    try replace_org(&contents);
    try replace_mermaid(&contents);
    var fm = try get_metadata(&contents);
    defer fm.deinit();

    panlog.debug("{}\n", .{fm});
}

fn replace_org(txt: *Array(u8)) !void {
    const size = std.mem.replacementSize(u8, txt.items, "{{ org() }}", org);
    const buf = try alloc.alloc(u8, size);

    _ = std.mem.replace(u8, txt.items, "{{ org() }}", org, buf);
    txt.deinit();
    txt.* = .{
        .allocator = alloc,
        .capacity = buf.len,
        .items = buf,
    };
}

fn replace_mermaid(txt: *Array(u8)) !void {
    const mermaid: mvzr.Regex = mvzr.compile("\\{%\\s*mermaid\\(\\)\\s*%\\}.+?\\{%\\s*end\\s*%\\}").?;
    // const mermaid_end: mvzr.Regex = mvzr.compile("\\{%\\s*end\\s*\\}").?;

    var replacements = Array(mvzr.Match).init(txt.allocator);
    defer {
        for (replacements.items) |r|
            r.deinit(alloc);
        replacements.deinit();
    }
    var iter = mermaid.iterator(txt.items);
    var total: usize = 0;
    while (iter.next()) |m| {
        try replacements.append(try m.toOwnedMatch(alloc));
        total += m.end - m.start;
    }

    for (replacements.items) |m| {
        const s = std.mem.indexOf(u8, m.slice, "%}") orelse return error.InvalidShortCode;
        const e = std.mem.lastIndexOf(u8, m.slice, "{%") orelse return error.InvalidShortCode;
        const inner = m.slice[s + 2 .. e - 2];
        const replace = try std.fmt.allocPrint(alloc, "~~~mermaid\n{s}\n~~~\n", .{inner});
        defer alloc.free(replace);

        const size = std.mem.replacementSize(u8, txt.items, m.slice, replace);
        const new = try alloc.alloc(u8, size);
        _ = std.mem.replace(u8, txt.items, m.slice, replace, new);
        txt.deinit();
        txt.* = .{
            .allocator = alloc,
            .capacity = new.len,
            .items = new,
        };
    }
}

pub fn find_md_files(root: std.fs.Dir, policy_dir: []const u8) ![]std.fs.File {
    panlog.debug("Reading in policies from: {s}\n", .{policy_dir});
    var files = Array(std.fs.File).init(alloc);
    defer files.deinit();
    var policy_root = try (try root.openDir("content", .{
        .access_sub_paths = true,
        .iterate = true,
    })).openDir(policy_dir, .{
        .access_sub_paths = true,
        .iterate = true,
    });
    defer policy_root.close();

    try find_inner(&files, policy_root);
    return try files.toOwnedSlice();
}
fn find_inner(files: *Array(std.fs.File), start: std.fs.Dir) !void {
    var iter = start.iterate();
    while (try iter.next()) |entry| {
        switch (entry.kind) {
            .file => {
                if (!std.mem.startsWith(u8, entry.name, "_") and
                    std.mem.endsWith(u8, entry.name, ".md"))
                    try files.append(try start.openFile(entry.name, .{ .mode = .read_only }));
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

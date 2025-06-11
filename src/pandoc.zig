//! This program automates the process of converting Markdown policy documents into styled PDF files.
//! It loads configuration from a TOML file, processes Markdown files (including YAML front matter and custom placeholders),
//! applies organization branding, and invokes Pandoc with a set of dynamically constructed arguments to generate PDFs.
//! The build is highly configurable, supporting custom logos, organization names, color extraction from images,
//! and options for draft/redacted document states. The system is designed for batch processing of policy directories,
//! with robust error handling and logging at multiple stages of the pipeline.
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const tomlz = @import("tomlz");
const Yaml = @import("yaml").Yaml;
const ctime = @cImport(@cInclude("time.h"));
const mvzr = @import("mvzr");

var global_args: Array([]u8) = undefined;
pub var global_config: Config = .{};

pub const Config = struct {
    org: []u8 = undefined,
    logo_path: []u8 = undefined,
    color: []u8 = undefined,
    current_year: []u8 = undefined,
    root: []u8 = undefined,
    is_draft: bool = false,
    redact: bool = false,
    build_dir: []const u8 = undefined,
    work_dir: std.fs.Dir = undefined,

    pub fn deinit(self: *Config, a: Allocator) void {
        a.free(self.org);
        a.free(self.logo_path);
        a.free(self.color);
        a.free(self.build_dir);
        a.free(self.current_year);
        a.free(self.root);
        self.work_dir.close();
    }

    pub fn init(a: Allocator) !Config {
        var dt_str_buf: [40]u8 = undefined;
        const t = ctime.time(null);
        const lt = ctime.localtime(&t);
        const format = "%Y";
        const dt_str_len = ctime.strftime(&dt_str_buf, dt_str_buf.len, format, lt);
        const current_year = dt_str_buf[0..dt_str_len];
        var self = Config{};
        self.current_year = try a.dupe(u8, current_year);
        self.root = std.process.getEnvVarOwned(a, "DEVBOX_PROJECT_ROOT") catch return error.ProjectRootNotFoundInEnv;
        self.work_dir = try std.fs.openDirAbsolute(
            self.root,
            .{
                .access_sub_paths = true,
                .iterate = true,
            },
        );
        try self.work_dir.makePath("public/pdf");
        self.build_dir = try self.work_dir.realpathAlloc(a, "public/pdf");

        return self;
    }
};

// TODO: Add more robust error propegation from pandoc/mermaid-filter
// TODO: Add threading support
// TODO: Add CLI args
// TODO?: Link against pandoc directly at somepoint

pub const std_options: std.Options = .{
    .log_level = .info,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .parser, .level = .debug },
        .{ .scope = .pandoc, .level = .info },
    },
    .logFn = logFn,
};
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

const panlog = std.log.scoped(.pandoc);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();
    global_config = try Config.init(alloc);
    var conf_file = try global_config.work_dir.openFile("config.toml", .{ .mode = .read_only });
    defer conf_file.close();

    const config_contents = try conf_file.readToEndAlloc(alloc, 100_000_000);
    defer alloc.free(config_contents);

    var config = try tomlz.parse(alloc, config_contents);
    defer config.deinit(alloc);
    var root_progress = Progress.start(.{
        .estimated_total_items = 0,
        .root_name = "Building PDFs from Markdown files",
    });
    defer root_progress.end();

    const extra = config.getTable("extra") orelse return error.NoExtraInConfig;
    const policy_root = extra.getString("policy_root") orelse return error.NoPolicyRootInExtra;
    const logo = extra.getString("logo") orelse return error.NoLogoInExtra;
    global_config.logo_path = try std.fmt.allocPrint(alloc, "static/{s}", .{logo});
    global_config.org = try alloc.dupe(u8, extra.getString("organization") orelse return error.NoOrgInExtra);
    global_config.color = try get_logo_color(alloc, global_config.logo_path, &root_progress);

    // const redact = b.option(bool, "redact", "Redact PDFs") orelse false;
    // const draft = b.option(bool, "redact", "Redact PDFs") orelse false;

    global_args = Array([]u8).init(alloc);
    defer {
        // for (global_args.items) |a|
        //     alloc.free(a);
        global_args.deinit();
    }

    try create_global_args(alloc, &global_args);
    defer destroy_global_args(alloc, global_args);

    const md_files = try find_md_files(alloc, global_config.work_dir, policy_root, &root_progress);
    defer {
        for (md_files) |f|
            f.deinit(alloc);
        alloc.free(md_files);
    }
    errdefer {
        for (md_files) |f|
            f.deinit(alloc);
        alloc.free(md_files);
    }
    const total_files = md_files.len;
    root_progress.setEstimatedTotalItems(total_files);
    panlog.debug("Building PDFs from {} markdown files in {s} .. \n", .{ total_files, policy_root });

    for (md_files) |f| {
        try process_md_file(alloc, f, &root_progress);
    }
    // try process_md_files_parallel(alloc, md_files);
}

pub fn destroy_global_args(a: Allocator, args: Array([]u8)) void {
    for (args.items) |arg|
        a.free(arg);
    args.deinit();
}

///Populates the global_args array with command-line arguments for Pandoc, based on the current global configuration
pub fn create_global_args(a: Allocator, args: *Array([]u8)) !void {
    try add_arg(a, args, "", "--data-dir={s}", .{global_config.root});
    try add_arg(a, args, "", "--resource-path={s}", .{global_config.root});
    try add_arg(a, args, "-V", "footer-left={s} \\textcopyright {s}", .{ global_config.org, global_config.current_year });

    try add_arg(a, args, "-V", "header-right=\\includegraphics[width=2cm,height=2cm]{{{s}}}", .{global_config.logo_path});

    try add_arg(a, args, "-V", "titlepage-logo={s}", .{global_config.logo_path});

    try add_arg(a, args, "-V", "institution=\"{s}\"", .{global_config.org});

    try add_arg(a, args, "-V", "titlepage-rule-color={s}", .{global_config.color[1..7]});

    try add_arg(a, args, "-F", "{s}/.devbox/nix/profile/default/bin/mermaid-filter", .{global_config.root});
    try add_arg(a, args, "-V", "footer-center=Confidental", .{});
    try add_arg(a, args, "-V", "papersize=letter", .{});
    try add_arg(a, args, "-V", "titlepage=true", .{});
    try add_arg(a, args, "-V", "toc-own-page=true ", .{});
    try add_arg(a, args, "-V", "toc=true", .{});
    try add_arg(a, args, "-V", "toc-depth=3", .{});
    try add_arg(a, args, "-V", "logo-width=6cm", .{});
    try add_arg(a, args, "-V", "table-use-row-colors=true", .{});
    try add_arg(a, args, "--template", "eisvogel", .{});
    try add_arg(a, args, "", "--listings", .{});
    try add_arg(a, args, "", "--webtex", .{});
    try add_arg(a, args, "", "--pdf-engine=xelatex", .{});

    if (global_config.is_draft) {
        try add_arg(a, args, "-V", "page-background=static/draft.png", .{});
        try add_arg(a, args, "-V", "page-background-opacity=0.8", .{});
    }
}

inline fn add_arg(
    a: Allocator,
    args: *Array([]u8),
    comptime prefix: []const u8,
    comptime fmt: []const u8,
    value: anytype,
) !void {
    if (prefix.len > 0) try args.append(try a.dupe(u8, prefix));

    const arg = try std.fmt.allocPrint(a, fmt, value);
    try args.append(arg);
}

/// Processes a single markdown file: loads contents, applies replacements, extracts metadata, writes a temporary file, and invokes Pandoc to generate the PDF.
pub fn process_md_file(a: Allocator, md: MDFile, prog: anytype) !void {
    var buf: [128]u8 = undefined;

    const fname = try std.fmt.bufPrint(&buf, "{s}/{s}", .{
        std.fs.path.basename((std.fs.path.dirname(md.path) orelse ".")),
        std.fs.path.basename(md.path),
    });
    var file = try std.fs.openFileAbsolute(md.path, .{ .mode = .read_only });
    defer file.close();

    var p = prog.start(fname, 4);
    defer p.end();
    const raw = try file.readToEndAlloc(a, 100_000_000);
    var contents = Array(u8){
        .items = raw,
        .allocator = a,
        .capacity = raw.len,
    };
    defer contents.deinit();
    var local = try global_args.clone();
    defer local.deinit();

    try replace_org(&contents, &p);
    try replace_mermaid(&contents, &p);

    var fm = try get_metadata(a, &contents, &p);
    defer fm.deinit(a);

    const tmp = try std.fs.cwd().createFile("tmp.md", std.fs.File.CreateFlags{ .exclusive = true });
    defer {
        tmp.close();
        std.fs.cwd().deleteFile("tmp.md") catch unreachable;
    }
    try tmp.writeAll(contents.items);

    try local.insert(0, try a.dupe(u8, "pandoc"));

    const res_path = try std.fmt.allocPrint(a, "--resource-path={s}", .{std.fs.path.dirname(md.path).?});
    try local.append(res_path);

    try local.append(try a.dupe(u8, "tmp.md"));

    const out = try fm.filename(a);
    std.mem.replaceScalar(u8, out, ' ', '_');
    try add_arg(a, &local, "-o", "{s}", .{out});
    try run_pandoc(a, local, &p);
}

/// Parses YAML front matter from a markdown file, extracts document metadata, formats the title, and returns a FrontMatter struct.
pub fn get_metadata(a: Allocator, txt: *Array(u8), prog: anytype) !FrontMatter {
    const p = prog.start("Get Metadata", 1);
    defer p.end();

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
    const title = if (global_config.redact and global_config.is_draft)
        try std.fmt.allocPrint(a, rd, .{t})
    else if (global_config.redact)
        try std.fmt.allocPrint(a, r, .{t})
    else if (global_config.is_draft)
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
        return std.fmt.allocPrint(a, "{s}/{s}_-_v{s}.pdf", .{ global_config.build_dir, self.title, self.most_recent_version });
    }

    pub fn deinit(self: *FrontMatter, a: Allocator) void {
        a.free(self.title);
        a.free(self.last_reviewed);
        a.free(self.most_recent_version);
    }
};

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
pub fn replace_org(txt: *Array(u8), prog: anytype) !void {
    const p = prog.start("Replace Organization Shortcode", 1);
    defer p.end();
    const orgsc: mvzr.Regex = mvzr.compile("\\{\\{\\s*org\\(\\)\\s*\\}\\}").?;

    if (!orgsc.isMatch(txt.items)) return;

    var new = try txt.clone();

    var iter = orgsc.iterator(txt.items);
    while (iter.next()) |match| {
        try new.replaceRange(match.start, match.slice.len, global_config.org);
        iter = orgsc.iterator(new.items);
    }
    txt.deinit();
    txt.* = new;
}

/// Finds and replaces custom Mermaid code blocks in the markdown with a standardized code block format.
pub fn replace_mermaid(txt: *Array(u8), prog: anytype) !void {
    const p = prog.start("Replace Mermaid Shortcode", 1);
    defer p.end();
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
    path: []u8,
    pub fn deinit(self: MDFile, a: Allocator) void {
        a.free(self.path);
    }
};

/// Recursively finds and opens all markdown files in the specified policy directory, returning them as an array of files.
pub fn find_md_files(a: Allocator, root: std.fs.Dir, policy_dir: []const u8, prog: *std.Progress.Node) ![]MDFile {
    var p = prog.start("Searching for markdown files in policy root", 1);
    defer p.end();

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

    try find_inner(&files, policy_root, &p);
    return try files.toOwnedSlice();
}
/// Helper function to recursively traverse directories and append markdown files to the provided array.
pub fn find_inner(files: *Array(MDFile), start: std.fs.Dir, prog: *std.Progress.Node) !void {
    var num: usize = 0;
    var iter = start.iterate();
    while (try iter.next()) |_| {
        num += 1;
    }
    var buf: [128]u8 = undefined;
    const dname = try start.realpath(".", &buf);
    var p = prog.start(dname, num);
    defer p.end();

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
                try find_inner(files, sub, &p);
            },
            else => {},
        }
    }
}

/// Runs an external command to extract the dominant color from the logo image and returns it as a string.
pub fn get_logo_color(a: Allocator, path: []const u8, prog: anytype) ![]u8 {
    const p = prog.start("Get Color From Logo", 1);
    defer p.end();
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

/// Spawns a Pandoc process with the provided arguments, collects output, and logs errors or results as needed.
pub fn run_pandoc(a: Allocator, args: Array([]u8), prog: *std.Progress.Node) !void {
    const p = prog.start("Executing Pandoc", 0);
    defer p.end();

    panlog.debug("Running pandoc with args:\n", .{});
    for (args.items) |arg|
        panlog.debug("\t{s}\n", .{arg});
    var child = std.process.Child.init(args.items, a);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    var env_map = try std.process.getEnvMap(a);
    defer env_map.deinit();
    child.env_map = &env_map;
    // Optionally, print or check the PATH in env_map
    if (env_map.get("PATH")) |path| {
        panlog.debug("Child PATH: {s}\n", .{path});
    } else {
        panlog.debug("No PATH in env_map!\n", .{});
    }
    var out: std.ArrayListUnmanaged(u8) = .empty;
    var err: std.ArrayListUnmanaged(u8) = .empty;
    defer {
        out.deinit(a);
        err.deinit(a);
    }
    try child.spawn();
    try child.collectOutput(a, &out, &err, 100_000);

    const exit_code = child.wait() catch |e| {
        panlog.err("Error in pandoc: {s}\nRan with: {s}\n", .{ err.items, args.items });
        return e;
    };
    panlog.debug("{any} {s}\n", .{ exit_code, out.items });
    if (err.items.len > 0) {
        panlog.err("{s}\n", .{err.items});
        return error.PandocError;
    }
}

const Progress = std.Progress;

pub fn process_md_files_parallel(allocator: Allocator, files: []std.fs.File) !void {
    const total_files = files.len;
    var root_progress = Progress.start(.{
        .estimated_total_items = total_files,
        .root_name = "Processing PDFs",
    });
    defer root_progress.end();

    var errors = std.ArrayList(anyerror).init(allocator);
    defer errors.deinit();
    var errors_mutex = std.Thread.Mutex{};

    var threads = std.ArrayList(std.Thread).init(allocator);
    defer {
        for (threads.items) |t| t.join();
        threads.deinit();
    }

    for (files) |file| {
        const thread = try std.Thread.spawn(.{}, struct {
            fn run(f: std.fs.File, root: *Progress.Node, errs: *std.ArrayList(anyerror), mtx: *std.Thread.Mutex) void {
                const local_alloc = std.heap.c_allocator;
                const file_progress = root.start("File", 1);
                defer file_progress.end();

                process_md_file(local_alloc, f) catch |err| {
                    mtx.lock();
                    defer mtx.unlock();
                    errs.append(err) catch {};
                };
                file_progress.completeOne();
            }
        }.run, .{ file, &root_progress, &errors, &errors_mutex });

        try threads.append(thread);
    }

    for (threads.items) |t| t.join();

    if (errors.items.len > 0) {
        std.log.err("Failed processing {} files:", .{errors.items.len});
        for (errors.items) |err| {
            std.log.err("- {s}", .{@errorName(err)});
        }
        return error.ProcessingFailed;
    }
}

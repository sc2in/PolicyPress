///! This program automates the process of converting Markdown policy documents into styled PDF files.
///! It loads configuration from a TOML file, processes Markdown files (including YAML front matter and custom placeholders),
///! applies organization branding, and invokes Pandoc with a set of dynamically constructed arguments to generate PDFs.
///! The build is highly configurable, supporting custom logos, organization names, color extraction from images,
///! and options for draft/redacted document states. The system is designed for batch processing of policy directories,
///! with robust error handling and logging at multiple stages of the pipeline.
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
var global_args: Array([]const u8) = undefined;
var global_config: struct {
    org: []u8 = undefined,
    logo_path: []u8 = undefined,
    color: []u8 = undefined,
    current_year: []u8 = undefined,
    root: []const u8 = undefined,
    is_draft: bool = false,
    redact: bool = false,

    pub fn deinit(self: @This()) void {
        alloc.free(self.org);
        alloc.free(self.logo_path);
        alloc.free(self.color);
    }
} = .{};

pub const std_options: std.Options = .{
    .log_level = .info,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .parser, .level = .debug },
        .{ .scope = .pandoc, .level = .debug },
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

    alloc = arena.allocator();

    var dt_str_buf: [40]u8 = undefined;
    const t = ctime.time(null);
    const lt = ctime.localtime(&t);
    const format = "%Y";
    const dt_str_len = ctime.strftime(&dt_str_buf, dt_str_buf.len, format, lt);
    const current_year = dt_str_buf[0..dt_str_len];
    global_config.current_year = current_year;
    global_config.root = std.posix.getenv("DEVBOX_PROJECT_ROOT") orelse return error.ProjectRootNotFoundInEnv;
    var workDir = try std.fs.openDirAbsolute(
        global_config.root,
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
    const policy_root = extra.getString("policy_root") orelse return error.NoPolicyRootInExtra;
    const logo = extra.getString("logo") orelse return error.NoLogoInExtra;
    global_config.logo_path = try std.fmt.allocPrint(alloc, "static/{s}", .{logo});
    global_config.org = try alloc.dupe(u8, extra.getString("organization") orelse return error.NoOrgInExtra);
    defer global_config.deinit();
    // const redact = b.option(bool, "redact", "Redact PDFs") orelse false;
    // const draft = b.option(bool, "redact", "Redact PDFs") orelse false;

    global_args = Array([]const u8).init(alloc);
    defer {
        // for (global_args.items) |a|
        //     alloc.free(a);
        global_args.deinit();
    }

    try create_global_args(&global_args);
    //TODO: Add output directory

    const md_files = try find_md_files(workDir, policy_root);
    defer {
        for (md_files) |f|
            f.close();
        alloc.free(md_files);
    }
    const total_files = md_files.len;
    std.debug.print("Building PDFs from {} markdown files in {s} .. \n", .{ total_files, policy_root });
    for (md_files) |f|
        try process_md_file(alloc, f);
    // try process_md_files_parallel(alloc, md_files);
}

///Populates the global_args array with command-line arguments for Pandoc, based on the current global configuration
fn create_global_args(args: *Array([]const u8)) !void {
    global_config.color = try get_logo_color(global_config.logo_path);

    const data_dir = try std.fmt.allocPrint(alloc, "--data-dir={s}", .{global_config.root});
    try args.append(data_dir);

    const res_dir = try std.fmt.allocPrint(alloc, "--resource-path={s}", .{global_config.root});
    try args.append(res_dir);

    const footer = try std.fmt.allocPrint(alloc, "footer-left={s} \\textcopyright {s}", .{ global_config.org, global_config.current_year });
    try args.appendSlice(&.{ "-V", footer });
    try args.appendSlice(&.{ "-V", "footer-center=Confidental" });

    const header = try std.fmt.allocPrint(alloc, "header-right=\\includegraphics[width=2cm,height=2cm]{{{s}}}", .{global_config.logo_path});
    try args.appendSlice(&.{ "-V", header });

    const logo = try std.fmt.allocPrint(alloc, "titlepage-logo={s}", .{global_config.logo_path});
    try args.appendSlice(&.{ "-V", logo });

    const inst = try std.fmt.allocPrint(alloc, "institution=\"{s}\"", .{global_config.org});
    try args.appendSlice(&.{ "-V", inst });

    const color = try std.fmt.allocPrint(alloc, "titlepage-rule-color={s}", .{global_config.color[1..7]});
    try args.appendSlice(&.{ "-V", color });

    try args.appendSlice(&.{ "-V", "papersize=letter" });
    try args.appendSlice(&.{ "-V", "titlepage=true" });
    try args.appendSlice(&.{ "-V", "table-use-row-colors=true " });
    try args.appendSlice(&.{ "-V", "logo-width=6cm" });
    try args.appendSlice(&.{ "-V", "toc-depth=3" });
    try args.appendSlice(&.{ "-V", "toc=true" });
    try args.appendSlice(&.{ "-V", "toc-own-page=true" });
    try args.appendSlice(&.{ "-V", "titlepage=true" });
    try args.appendSlice(&.{ "--template", "eisvogel" });
    try args.append("--webtex");
    try args.append("--listings");
    try args.append("--pdf-engine=xelatex");

    if (global_config.is_draft) {
        try args.appendSlice(&.{ "-V", "page-background=static/draft.png" });
        try args.appendSlice(&.{ "-V", "page-background-opacity=0.8" });
    }
    //TODO
    // try args.append("-F mermaid-filter");
}
/// Processes a single markdown file: loads contents, applies replacements, extracts metadata, writes a temporary file, and invokes Pandoc to generate the PDF.
fn process_md_file(a: Allocator, md: std.fs.File) !void {
    const raw = try md.readToEndAlloc(alloc, 100_000_000);
    var contents = Array(u8){
        .items = raw,
        .allocator = a,
        .capacity = raw.len,
    };
    defer contents.deinit();
    var local = try global_args.clone();
    defer local.deinit();

    try replace_org(&contents);
    try replace_mermaid(&contents);
    var fm = try get_metadata(&contents);
    defer fm.deinit();

    const tmp = try std.fs.cwd().createFile("tmp.md", .{});
    defer {
        tmp.close();
        std.fs.cwd().deleteFile("tmp.md") catch unreachable;
    }
    try tmp.writeAll(contents.items);

    panlog.debug("{}\n", .{fm});
    try local.insert(0, "pandoc");
    const out_file = try fm.filename(a);
    // defer alloc.free(out_file);

    try local.appendSlice(&.{ "tmp.md", "-o", out_file });
    //TODO: Add the local resource folder
    try run_pandoc(a, local);
}

/// Parses YAML front matter from a markdown file, extracts document metadata, formats the title, and returns a FrontMatter struct.
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

    const rd = "{s} (Redacted) (Draft)";
    const r = "{s} (Redacted)";
    const d = "{s} (Draft)";
    const e = "{s}";
    const t = map.get("title").?.string;
    const title = if (global_config.redact and global_config.is_draft)
        try std.fmt.allocPrint(alloc, rd, .{t})
    else if (global_config.redact)
        try std.fmt.allocPrint(alloc, r, .{t})
    else if (global_config.is_draft)
        try std.fmt.allocPrint(alloc, d, .{t})
    else
        try std.fmt.allocPrint(alloc, e, .{t});

    return .{
        .title = title,
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
        return std.fmt.allocPrint(a, "{s} - v{s}.pdf", .{ self.title, self.most_recent_version });
    }

    pub fn deinit(self: *FrontMatter) void {
        alloc.free(self.title);
        alloc.free(self.last_reviewed);
        alloc.free(self.most_recent_version);
    }
};

/// Comparator function for sorting YAML revision values in ascending order.
fn revisions_lt(_: @TypeOf(.{}), a: Yaml.Value, b: Yaml.Value) bool {
    const as = a.string;
    const bs = b.string;

    for (as, 0..) |ac, i| {
        if (ac < bs[i]) return true;
    }
    return false;
}

/// Replaces all instances of the organization placeholder in the markdown text with the actual organization name from the global configuration.
fn replace_org(txt: *Array(u8)) !void {
    const size = std.mem.replacementSize(
        u8,
        txt.items,
        "{{ org() }}",
        global_config.org,
    );
    const buf = try alloc.alloc(u8, size);

    _ = std.mem.replace(
        u8,
        txt.items,
        "{{ org() }}",
        global_config.org,
        buf,
    );
    txt.deinit();
    txt.* = .{
        .allocator = alloc,
        .capacity = buf.len,
        .items = buf,
    };
}

/// Finds and replaces custom Mermaid code blocks in the markdown with a standardized code block format.
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

/// Recursively finds and opens all markdown files in the specified policy directory, returning them as an array of files.
pub fn find_md_files(root: std.fs.Dir, policy_dir: []const u8) ![]std.fs.File {
    panlog.info("Reading in policies from: {s}\n", .{policy_dir});
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
/// Helper function to recursively traverse directories and append markdown files to the provided array.
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

/// Runs an external command to extract the dominant color from the logo image and returns it as a string.
fn get_logo_color(path: []const u8) ![]u8 {
    const argv = [_][]const u8{
        "magick",
        path,
        "-scale",
        "1x1\\!",
        "-format",
        "'%[hex:u]'",
        "info:",
    };
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
    panlog.debug("{any} {s}\n", .{ exit_code, err.items });
    return try out.toOwnedSlice(alloc);
}

/// Spawns a Pandoc process with the provided arguments, collects output, and logs errors or results as needed.
fn run_pandoc(a: Allocator, args: Array([]const u8)) !void {
    panlog.debug("Running pandoc with args:\n", .{});
    for (args.items) |arg|
        panlog.debug("\t{s}\n", .{arg});
    var child = std.process.Child.init(args.items, a);
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

    const exit_code = child.wait() catch |e| {
        panlog.err("Error in pandoc: {s}\nRan with: {s}\n", .{ err.items, args.items });
        return e;
    };
    panlog.debug("{any} {s}\n", .{ exit_code, out.items });
    if (err.items.len > 0)
        panlog.err("{s}\n", .{err.items});
}

const Progress = std.Progress;

fn process_md_files_parallel(allocator: Allocator, files: []std.fs.File) !void {
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

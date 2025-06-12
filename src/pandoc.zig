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
const clap = @import("clap");
const u = @import("utils.zig");

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
// TODO?: Link against pandoc directly at somepoint

pub const std_options: std.Options = .{
    .log_level = .info,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .parser, .level = .debug },
        .{ .scope = .pandoc, .level = .info },
    },
    .logFn = u.logFn,
};

const panlog = std.log.scoped(.pandoc);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();
    global_config = try Config.init(alloc);

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-d, --draft            Add draft watermark to output.
        \\-r, --redact           Redact text within redaction tags in output.
        \\
    );
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        // Report useful error and exit.
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();
    if (res.args.help != 0) {
        std.debug.print("SC2 Policy Center PDF Generator\nSee Readme.md or run `devbox build docs` to learn more.\n\n", .{});
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }
    if (res.args.draft != 0) {
        panlog.warn("Draft mode enabled\n", .{});
        global_config.is_draft = true;
    }
    if (res.args.redact != 0) {
        panlog.warn("Redaction enabled\n", .{});
        global_config.redact = true;
    }

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
    global_config.color = try u.get_logo_color(alloc, global_config.logo_path, &root_progress);

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

    const md_files = try u.find_md_files(alloc, global_config.work_dir, policy_root, &root_progress);
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
pub fn process_md_file(a: Allocator, md: u.MDFile, prog: anytype) !void {
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

    try u.replace_org(&contents, &p);
    try u.replace_mermaid(&contents, &p);

    var fm = try u.get_metadata(a, &contents, &p);
    defer fm.deinit(a);

    const tmp = try std.fs.cwd().createFile("tmp.md", std.fs.File.CreateFlags{ .exclusive = true });
    errdefer {
        std.fs.cwd().deleteFile("tmp.md") catch unreachable;
    }
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
        panlog.err("!!! {s}\n!!! Called with:\n", .{err.items});
        for (args.items) |arg|
            panlog.err("\t{s}\n", .{arg});
        // return error.PandocError;
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

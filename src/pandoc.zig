//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: AGPL-3.0-or-later
//!
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
const FrontMatter = @import("FM");
const tomlz = FrontMatter.tomlz;
const Yaml = FrontMatter.Yaml;
const ctime = @cImport(@cInclude("time.h"));
const mvzr = @import("mvzr");
const clap = @import("clap");
const u = @import("utils");

const Config = @import("config").Config;

// TODO: Add more robust error propegation from pandoc/mermaid-filter
// TODO: Add threading support
// TODO?: Link against pandoc directly at somepoint

pub const std_options: std.Options = .{
    .log_level = .warn,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .parser, .level = .warn },
        .{ .scope = .pandoc, .level = .warn },
        .{ .scope = .yaml, .level = .err },
    },
    .logFn = u.logFn,
};

const panlog = std.log.scoped(.pandoc);

pub fn compile(
    alloc: Allocator,
    config: Config,
    input_file: []const u8,
) !void {
    var global_args = Array([]u8){};

    try create_global_args(alloc, &global_args, config);
    defer destroy_global_args(alloc, &global_args);

    try process_md_file(alloc, .{ .path = input_file }, global_args, config);
}
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    var config = try Config.load_config_toml(alloc);
    errdefer config.deinit(alloc);
    defer config.deinit(alloc);

    var workfile: ?[]u8 = null;
    defer {
        if (workfile) |w| alloc.free(w);
    }

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-d, --draft            Add draft watermark to output.
        \\-r, --redact           Redact text within redaction tags in output.
        \\--org <str>            Organization name
        \\-o, --output <str>     Destination folder
        \\-i, --input <str>      Input file
    );
    var buf: [128]u8 = undefined;

    // Report useful error and exit.
    var stderr = std.fs.File.stderr().writer(&buf).interface;
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(&stderr, err) catch {};
        return err;
    };
    // std.debug.print("{any}", .{res});
    defer res.deinit();
    if (res.args.help != 0) {
        std.debug.print("SC2 Policy Center PDF Generator\nSee Readme.md or run `devbox build docs` to learn more.\n\n", .{});
        return clap.helpToFile(std.fs.File.stderr(), clap.Help, &params, .{});
    }

    if (res.args.output) |c| {
        panlog.info("Writing to: {s}\n", .{c});
        config.build_dir = try alloc.dupe(u8, c);
    } else return error.OutputDirNotProvided;
    if (res.args.input) |c| {
        panlog.info("Input File: {s}\n", .{c});
        workfile = try alloc.dupe(u8, c);
    } else return error.InputFileNotProvided;

    if (res.args.draft != 0) {
        panlog.info("Draft mode enabled\n", .{});
        config.is_draft = true;
    }
    if (res.args.redact != 0 or config.redact == true) {
        panlog.info("Redaction enabled\n", .{});
        config.redact = true;
    }

    panlog.debug("Running with Configuration:\n{f}\n", .{config});

    var global_args = Array([]u8){};

    try create_global_args(alloc, &global_args, config);
    defer destroy_global_args(alloc, &global_args);
    if (workfile) |w|
        try process_md_file(
            alloc,
            .{ .path = w },
            global_args,
            config,
        )
    else
        return error.InputFileNotProvided;
}

pub fn destroy_global_args(a: Allocator, args: *Array([]u8)) void {
    for (args.items) |arg|
        a.free(arg);
    args.deinit(a);
}

///Populates the global_args array with command-line arguments for Pandoc, based on the current global configuration
pub fn create_global_args(a: Allocator, args: *Array([]u8), config: Config) !void {
    try add_arg(a, args, "", "--data-dir={s}", .{config.root});
    try add_arg(a, args, "", "--resource-path={s}", .{config.root});
    try add_arg(a, args, "-V", "footer-left={s} \\textcopyright {d}", .{ config.org, config.current_year });

    try add_arg(a, args, "-V", "header-right=\\includegraphics[width=2cm,height=2cm]{{{s}}}", .{config.logo_path});

    try add_arg(a, args, "-V", "titlepage-logo={s}", .{config.logo_path});

    try add_arg(a, args, "-V", "institution=\"{s}\"", .{config.org});

    try add_arg(a, args, "-V", "titlepage-rule-color={s}", .{if (config.color[0] == '#') config.color[1..] else config.color});

    try add_arg(a, args, "-F", "{s}/.devbox/nix/profile/default/bin/mermaid-filter", .{config.root});
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

    if (config.is_draft) {
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
    if (prefix.len > 0) try args.append(a, try a.dupe(u8, prefix));

    const arg = try std.fmt.allocPrint(a, fmt, value);
    try args.append(a, arg);
}

/// Processes a single markdown file: loads contents, applies replacements, extracts metadata, writes a temporary file, and invokes Pandoc to generate the PDF.
pub fn process_md_file(
    a: Allocator,
    md: u.MDFile,
    global_args: Array([]u8),
    config: Config,
) !void {
    panlog.debug("Processing markdown file: {s}\n", .{md.path});
    var dir = try std.fs.cwd().openDir(config.root, .{});
    defer dir.close();
    var file = dir.openFile(md.path, .{ .mode = .read_only }) catch |e| {
        if (e == error.FileNotFound) {
            panlog.err("File: {s}/{s} not found\n", .{ config.root, md.path });
        }
        return e;
    };
    defer file.close();

    const raw = try file.readToEndAlloc(a, 100_000_000);
    var contents = Array(u8){
        .items = raw,
        .capacity = raw.len,
    };
    defer contents.deinit(a);
    var local = Array([]u8){};
    defer destroy_global_args(a, &local);

    try u.replace_org(a, &contents, config.org);
    try u.replace_zola_at(a, &contents, config.base_url);
    try u.replace_mermaid(a, &contents);
    try u.redact(a, &contents, config.redact);

    var fm = try u.get_metadata(a, &contents, config);
    defer fm.deinit(a);

    var build = std.fs.cwd().openDir(config.build_dir, .{
        .access_sub_paths = true,
    }) catch |e| {
        panlog.err("Could not open directory for build: {s}\nError: {}\n", .{ config.build_dir, e });
        return e;
    };
    defer build.close();

    const tmp_file = std.fs.path.basename(md.path);
    const tmp = build.createFile(tmp_file, std.fs.File.CreateFlags{ .exclusive = true }) catch |e| blk: {
        if (e == error.PathAlreadyExists) {
            build.deleteFile(tmp_file) catch unreachable;
            break :blk try build.createFile(tmp_file, std.fs.File.CreateFlags{ .exclusive = true });
        }
        return e;
    };

    defer {
        tmp.close();
        build.deleteFile(tmp_file) catch unreachable;
    }
    try tmp.writeAll(contents.items);

    try local.insertSlice(a, 0, &.{try a.dupe(u8, "pandoc")});
    const cwd = try std.fs.cwd().realpathAlloc(a, ".");
    defer a.free(cwd);

    var env = try std.process.getEnvMap(a);
    defer env.deinit();

    const basedir = if (std.fs.path.dirname(md.path)) |d| try a.dupe(u8, d) else return error.NoResourcePathDefined;
    defer a.free(basedir);
    const res_path = try std.fmt.allocPrint(a, "--resource-path={s}:{s}:{s}/templates", .{ env.get("PATH") orelse "", basedir, cwd });
    try local.append(a, res_path);

    try local.append(a, try std.fs.path.join(a, &.{ config.build_dir, tmp_file }));

    const out = try fm.filename(a);
    defer a.free(out);
    std.mem.replaceScalar(u8, out, ' ', '_');

    // Sanitize the output filename to prevent path traversal and unsafe characters.
    var prev_dot = false;
    for (out, 0..) |*ch, idx| {
        var c = ch.*;
        // Replace any path separators with an underscore.
        if (c == '/' or c == '\\') {
            c = '_';
        }
        // Allow only alphanumerics, '_', '-', and '.'; map others to '_'.
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-' and c != '.') {
            c = '_';
        }
        // Prevent leading '.' and ".." sequences.
        if (c == '.') {
            if (idx == 0 or prev_dot) {
                c = '_';
                prev_dot = false;
            } else {
                prev_dot = true;
            }
        } else {
            prev_dot = false;
        }
        ch.* = c;
    }

    try add_arg(a, &local, "-o", "{s}{s}{s}", .{ config.build_dir, "/", out });

    var combined = Array([]const u8){};
    defer combined.deinit(a);

    try combined.appendSlice(a, local.items);
    try combined.appendSlice(a, global_args.items);

    try run_pandoc(a, combined);
}

/// Spawns a Pandoc process with the provided arguments, collects output, and logs errors or results as needed.
pub fn run_pandoc(a: Allocator, args: Array([]const u8)) !void {
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
        panlog.err("Error in pandoc: {s}\nRan with: {any}\n", .{ err.items, args.items });
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

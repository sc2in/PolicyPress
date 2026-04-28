//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;

const clap = @import("clap");
const Config = @import("config").Config;
const mvzr = @import("mvzr");
const u = @import("utils");

const ctime = @cImport(@cInclude("time.h"));
// TODO: Add more robust error propegation from pandoc/mermaid-filter
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
        std.debug.print("PolicyPress PDF Generator\nSee Readme.md or run `devbox build docs` to learn more.\n\n", .{});
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

/// Writes the embedded eisvogel.latex into `<dir>/templates/eisvogel.latex`
/// and returns the allocated path to `<dir>` for use as `--data-dir`.
/// The template is injected at build time via the `pandoc_options` module.
/// Caller owns the returned slice.
pub fn writeEisvogel(a: Allocator, dir: []const u8) ![]const u8 {
    const tmpl_dir = try std.fs.path.join(a, &.{ dir, "templates" });
    defer a.free(tmpl_dir);
    try std.fs.makeDirAbsolute(tmpl_dir);
    const tmpl_path = try std.fs.path.join(a, &.{ tmpl_dir, "eisvogel.latex" });
    defer a.free(tmpl_path);
    const f = try std.fs.createFileAbsolute(tmpl_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(@import("pandoc_options").eisvogel_latex);
    return try a.dupe(u8, dir);
}

///Populates the global_args array with command-line arguments for Pandoc, based on the current global configuration
pub fn create_global_args(a: Allocator, args: *Array([]u8), config: Config) !void {
    const data_dir = if (config.data_dir.len > 0) config.data_dir else config.root;
    try add_arg(a, args, "", "--data-dir={s}", .{data_dir});
    try add_arg(a, args, "", "--resource-path={s}", .{config.root});
    try add_arg(a, args, "-V", "footer-left={s} \\textcopyright {d}", .{ config.org, config.current_year });

    // LaTeX treats '%' as a comment character in file paths fed to \includegraphics.
    // Copy the logo to a unique temp path without special characters when the path contains '%'.
    const logo_for_latex = if (std.mem.indexOfScalar(u8, config.logo_path, '%') != null) blk: {
        const ext = std.fs.path.extension(config.logo_path);
        var attempt: usize = 0;
        while (attempt < 16) : (attempt += 1) {
            const tmp_path = try std.fmt.allocPrint(a, "/tmp/pp-logo-{x}{s}", .{ std.crypto.random.int(u64), ext });
            // Claim the path exclusively to avoid races, then overwrite with the real content.
            const tmp_file = std.fs.createFileAbsolute(tmp_path, .{ .exclusive = true }) catch |err| {
                a.free(tmp_path);
                if (err == error.PathAlreadyExists) continue;
                std.log.warn("could not create temp logo file: {}", .{err});
                break :blk try a.dupe(u8, config.logo_path);
            };
            tmp_file.close();
            std.fs.copyFileAbsolute(config.logo_path, tmp_path, .{}) catch |err| {
                std.fs.deleteFileAbsolute(tmp_path) catch {};
                a.free(tmp_path);
                std.log.warn("could not copy logo to temp path: {}", .{err});
                break :blk try a.dupe(u8, config.logo_path);
            };
            break :blk tmp_path;
        }
        std.log.warn("could not allocate a unique temp logo file name", .{});
        break :blk try a.dupe(u8, config.logo_path);
    } else try a.dupe(u8, config.logo_path);
    defer a.free(logo_for_latex);
    try add_arg(a, args, "-V", "header-right=\\includegraphics[width=2cm,height=2cm]{{{s}}}", .{logo_for_latex});

    try add_arg(a, args, "-V", "titlepage-logo={s}", .{logo_for_latex});

    try add_arg(a, args, "-V", "institution=\"{s}\"", .{config.org});

    try add_arg(a, args, "-V", "titlepage-rule-color={s}", .{if (config.color[0] == '#') config.color[1..] else config.color});

    if (executableInPath("mermaid-filter"))
        try add_arg(a, args, "-F", "mermaid-filter", .{});
    try add_arg(a, args, "-V", "footer-center=Confidential", .{});
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

pub fn executableInPath(name: []const u8) bool {
    const path_env = std.posix.getenv("PATH") orelse return false;
    var it = std.mem.tokenizeScalar(u8, path_env, ':');
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    while (it.next()) |dir| {
        const full = std.fmt.bufPrint(&buf, "{s}/{s}", .{ dir, name }) catch continue;
        std.fs.accessAbsolute(full, .{}) catch continue;
        return true;
    }
    return false;
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
    try u.replace_admonitions(a, &contents);
    try u.replace_mermaid(a, &contents);
    try u.redact(a, &contents, config.redact);

    var fm = try u.get_metadata(a, &contents, config);
    defer fm.deinit(a);

    var env = try std.process.getEnvMap(a);
    defer env.deinit();

    // Write the preprocessed markdown to a file in the system temp directory
    // rather than the output directory. This keeps .md files out of paths that
    // watchexec monitors, preventing false rebuild triggers.
    const tmpdir = blk: {
        const candidates = [_]?[]const u8{ env.get("TMPDIR"), env.get("TMP"), "/tmp" };
        for (candidates) |maybe| {
            const d = maybe orelse continue;
            std.fs.accessAbsolute(d, .{}) catch continue;
            break :blk d;
        }
        break :blk "/tmp";
    };
    const pid = std.os.linux.getpid();
    const tmp_name = try std.fmt.allocPrint(a, "pp_{d}_{s}", .{ pid, std.fs.path.basename(md.path) });
    defer a.free(tmp_name);
    const tmp_abs = try std.fs.path.join(a, &.{ tmpdir, tmp_name });
    defer a.free(tmp_abs);
    const tmp = std.fs.createFileAbsolute(tmp_abs, .{ .exclusive = true }) catch |e| blk: {
        if (e == error.PathAlreadyExists) {
            std.fs.deleteFileAbsolute(tmp_abs) catch {};
            break :blk try std.fs.createFileAbsolute(tmp_abs, .{});
        }
        return e;
    };
    defer {
        tmp.close();
        std.fs.deleteFileAbsolute(tmp_abs) catch {};
    }
    try tmp.writeAll(contents.items);

    // Verify output directory is still accessible before invoking pandoc.
    std.fs.cwd().access(config.build_dir, .{}) catch |e| {
        panlog.err("Could not access build directory: {s}\nError: {}\n", .{ config.build_dir, e });
        return e;
    };

    try local.insertSlice(a, 0, &.{try a.dupe(u8, "pandoc")});
    const cwd = try std.fs.cwd().realpathAlloc(a, ".");
    defer a.free(cwd);

    const basedir = if (std.fs.path.dirname(md.path)) |d| try a.dupe(u8, d) else return error.NoResourcePathDefined;
    defer a.free(basedir);
    const res_path = try std.fmt.allocPrint(a, "--resource-path={s}:{s}:{s}/templates", .{ env.get("PATH") orelse "", basedir, cwd });
    try local.append(a, res_path);

    // Pass the absolute temp file path and tell pandoc to read it as markdown
    // (since the .md extension is on the tmp file, format inference still works).
    try local.append(a, try a.dupe(u8, tmp_abs));

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

    // xelatex/fontconfig need a writable HOME to write their caches.  In the
    // Nix build sandbox HOME is set to /homeless-shelter (read-only), which
    // causes fontconfig to error and xelatex to exit non-zero.  Override HOME
    // with a directory under TMPDIR when the current value is not writable.
    const home_ok = if (env_map.get("HOME")) |h|
        (std.fs.accessAbsolute(h, .{}) catch null) != null
    else
        false;
    if (!home_ok) {
        const tmpdir = env_map.get("TMPDIR") orelse env_map.get("TMP") orelse "/tmp";
        const tmp_home = try std.fmt.allocPrint(a, "{s}/pp-home", .{tmpdir});
        defer a.free(tmp_home);
        std.fs.makeDirAbsolute(tmp_home) catch {};
        try env_map.put("HOME", tmp_home);
        panlog.debug("HOME not writable - overriding with {s}\n", .{tmp_home});
    }

    child.env_map = &env_map;
    if (env_map.get("PATH")) |path| {
        panlog.debug("Child PATH: {s}\n", .{path});
    } else {
        panlog.debug("No PATH in env_map!\n", .{});
    }
    var out: std.ArrayListUnmanaged(u8) = .empty;
    var err_buf: std.ArrayListUnmanaged(u8) = .empty;
    defer {
        out.deinit(a);
        err_buf.deinit(a);
    }

    child.spawn() catch |e| {
        if (e == error.FileNotFound) {
            std.debug.print(
                "policypress: pandoc not found in PATH.\n" ++
                    "Make sure you are running inside the PolicyPress devshell:\n\n" ++
                    "  nix develop github:sc2in/policypress\n\n",
                .{},
            );
            return error.PandocNotFound;
        }
        std.debug.print("policypress: failed to spawn pandoc: {s}\n", .{@errorName(e)});
        return e;
    };

    try child.collectOutput(a, &out, &err_buf, 100_000);

    const term = child.wait() catch |e| {
        std.debug.print(
            "policypress: error waiting for pandoc: {s}\n",
            .{@errorName(e)},
        );
        return e;
    };

    const exited_ok = switch (term) {
        .Exited => |code| code == 0,
        else => false,
    };

    if (!exited_ok) {
        // Print pandoc's stderr so the user can see the LaTeX/filter error.
        if (err_buf.items.len > 0) {
            std.debug.print("policypress: pandoc error output:\n{s}\n", .{err_buf.items});
        }
        return error.PandocFailed;
    }

    panlog.debug("{any} {s}\n", .{ term, out.items });
    if (err_buf.items.len > 0) {
        // Pandoc exited successfully but filters (e.g. mermaid-filter) wrote to
        // stderr. Log at warn rather than err so the test runner doesn't mark the
        // test as "logged errors" for expected sandbox noise.
        panlog.warn("!!! {s}\n!!! Called with:\n", .{err_buf.items});
        for (args.items) |arg|
            panlog.warn("\t{s}\n", .{arg});
    }
}

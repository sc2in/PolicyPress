//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
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
const build_options = @import("build_options");

const clap = @import("clap");
const Config = @import("config").Config;
const Pandoc = @import("pandoc");
const Reports = @import("reports");
const stampIsNewer = @import("utils").stampIsNewer;
const writeStamp = @import("utils").writeStamp;
const dt = @import("datetime");

const top_level_usage =
    \\Usage: policypress [SUBCOMMAND] [OPTIONS]
    \\
    \\Subcommands:
    \\  build   Build PDFs from policy Markdown files (default when no subcommand given)
    \\  new     Scaffold a new policy file
    \\  help    Show this message
    \\
    \\Run 'policypress <subcommand> --help' for subcommand-specific help.
    \\
;

pub fn main() void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Read argv upfront so we can route subcommands before clap sees the args.
    const argv = std.process.argsAlloc(alloc) catch {
        std.debug.print("policypress: out of memory\n", .{});
        std.process.exit(1);
    };
    defer std.process.argsFree(alloc, argv);

    // argv[0] is the binary name; user arguments start at argv[1].
    const user_args: []const [:0]u8 = if (argv.len > 1) argv[1..] else &.{};

    // If the first user argument looks like a subcommand (no leading '-'), dispatch.
    if (user_args.len > 0 and !std.mem.startsWith(u8, user_args[0], "-")) {
        const subcmd = user_args[0];
        const rest: []const [:0]u8 = if (user_args.len > 1) user_args[1..] else &.{};

        if (std.mem.eql(u8, subcmd, "new")) {
            runNew(alloc, rest) catch |err| {
                std.debug.print("policypress new: unexpected error: {s}\n", .{@errorName(err)});
                std.process.exit(1);
            };
            return;
        } else if (std.mem.eql(u8, subcmd, "build")) {
            runBuild(alloc, rest) catch |err| handleBuildError(err);
            return;
        } else if (std.mem.eql(u8, subcmd, "help")) {
            std.debug.print("{s}", .{top_level_usage});
            return;
        } else {
            std.debug.print("policypress: unknown subcommand '{s}'\n\n{s}", .{ subcmd, top_level_usage });
            std.process.exit(1);
        }
    }

    // Default: build (passing all user args as flags).
    runBuild(alloc, user_args) catch |err| handleBuildError(err);
}

fn handleBuildError(err: anyerror) void {
    switch (err) {
        // Errors that runBuild() already printed a message for — just exit.
        error.ConfigNotFound,
        error.ConfigReadFailed,
        error.ConfigInvalid,
        error.PolicyDirNotFound,
        error.PolicyDirUnreadable,
        error.OutputDirFailed,
        error.CompilationFailed,
        => {},
        // Anything unexpected.
        else => std.debug.print(
            "policypress: unexpected error: {s}\n",
            .{@errorName(err)},
        ),
    }
    std.process.exit(1);
}

fn runBuild(alloc: Allocator, args: []const [:0]u8) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-c, --config <str>     Path to config file. (default: config.toml)
        \\-i, --input  <str>     Path to input content directory. (default: content)
        \\-o, --output <str>     Path to output directory. (default: <prefix>/pdfs)
        \\--draft                Add draft watermark to output (overrides config.toml).
        \\--no-draft             Do not add draft watermark to output (overrides config.toml).
        \\--redact               Redact content within redaction tags (overrides config.toml).
        \\--no-redact            Do not redact text within redaction tags (overrides config.toml).
        \\-v, --verbose          Enable verbose logging.
    );
    var buf: [128]u8 = undefined;
    var stderr = std.fs.File.stderr().writer(&buf).interface;
    defer stderr.flush() catch {};
    var diag = clap.Diagnostic{};

    // Convert the sentinel-terminated slice to []const u8 for SliceIterator.
    var arg_strs = try alloc.alloc([]const u8, args.len);
    defer alloc.free(arg_strs);
    for (args, 0..) |a, i| arg_strs[i] = a;
    var iter = clap.args.SliceIterator{ .args = arg_strs };

    var res = clap.parseEx(clap.Help, &params, clap.parsers.default, &iter, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(&stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("PolicyPress\n\n", .{});
        return clap.helpToFile(std.fs.File.stderr(), clap.Help, &params, .{});
    }

    // --- Load config ---

    const config_path = if (res.args.config) |c| c else "config.toml";
    const config_file = std.fs.cwd().openFile(config_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print(
                \\policypress: config file '{s}' not found.
                \\
                \\Create a config.toml with at minimum:
                \\
                \\  base_url = "https://security.example.com"
                \\  theme    = "policypress"
                \\
                \\  [extra.policypress]
                \\  organization = "Example Co"
                \\  logo         = "logo.png"
                \\  pdf_color    = "#0e90f3"
                \\  policy_dir   = "policies/"
                \\
                \\See the configuration guide for all options.
                \\
            , .{config_path});
            return error.ConfigNotFound;
        }
        std.debug.print(
            "policypress: cannot open config file '{s}': {s}\n",
            .{ config_path, @errorName(err) },
        );
        return error.ConfigReadFailed;
    };
    defer config_file.close();
    const contents = config_file.readToEndAlloc(alloc, 1024 * 1024) catch |err| {
        std.debug.print(
            "policypress: failed to read config file '{s}': {s}\n",
            .{ config_path, @errorName(err) },
        );
        return error.ConfigReadFailed;
    };
    defer alloc.free(contents);

    var config = Config.load(alloc, contents) catch |err| {
        printConfigError(config_path, err);
        return error.ConfigInvalid;
    };
    defer config.deinit(alloc);

    if (res.args.draft != 0) config.is_draft = true;
    if (res.args.@"no-draft" != 0) config.is_draft = false;
    if (res.args.redact != 0) config.redact = true;
    if (res.args.@"no-redact" != 0) config.redact = false;

    //TODO: Verbosity
    std.log.debug("Running PolicyPress with configuration:\n{f}\n", .{config});

    // --- Open policy directory ---

    var policy_dir = std.fs.cwd().openDir(config.policy_dir, .{
        .iterate = true,
        .access_sub_paths = true,
    }) catch |err| {
        if (err == error.FileNotFound or err == error.NotDir) {
            std.debug.print(
                "policypress: policy directory '{s}' not found.\n" ++
                    "Check that 'policy_dir' in config.toml [extra] points to an existing directory under content/.\n",
                .{config.policy_dir},
            );
        } else {
            std.debug.print(
                "policypress: cannot open policy directory '{s}': {s}\n",
                .{ config.policy_dir, @errorName(err) },
            );
        }
        return error.PolicyDirNotFound;
    };
    defer policy_dir.close();

    var walker = policy_dir.walk(alloc) catch |err| {
        std.debug.print(
            "policypress: failed to read policy directory '{s}': {s}\n",
            .{ config.policy_dir, @errorName(err) },
        );
        return error.PolicyDirUnreadable;
    };
    defer walker.deinit();

    // --- Resolve output directory ---

    const prefix = build_options.install_prefix;
    const default_output = if (prefix.len > 0 and !std.fs.path.isAbsolute(prefix))
        try std.fmt.allocPrint(alloc, "{s}/pdfs", .{prefix})
    else
        try alloc.dupe(u8, "public/pdfs");
    defer alloc.free(default_output);

    const output_path = if (res.args.output) |o| o else default_output;
    config.build_dir = output_path;

    // Write the embedded eisvogel.latex to a tmpdir so pandoc can find it
    // without the consumer needing to vendor the template in their repository.
    const data_dir_path = blk: {
        var env_tmp = try std.process.getEnvMap(alloc);
        defer env_tmp.deinit();
        const base = env_tmp.get("TMPDIR") orelse env_tmp.get("TMP") orelse "/tmp";
        break :blk try std.fmt.allocPrint(alloc, "{s}/pp-data-{d}", .{ base, std.os.linux.getpid() });
    };
    defer alloc.free(data_dir_path);
    std.fs.makeDirAbsolute(data_dir_path) catch {};
    defer std.fs.deleteTreeAbsolute(data_dir_path) catch {};
    config.data_dir = Pandoc.writeEisvogel(alloc, data_dir_path) catch |err| blk: {
        std.debug.print("policypress: warning: could not write embedded template ({s}), falling back to --data-dir=.\n", .{@errorName(err)});
        break :blk config.root;
    };
    defer if (!std.mem.eql(u8, config.data_dir, config.root)) alloc.free(config.data_dir);

    std.fs.cwd().makePath(output_path) catch |err| {
        std.debug.print(
            "policypress: cannot create output directory '{s}': {s}\n",
            .{ output_path, @errorName(err) },
        );
        return error.OutputDirFailed;
    };

    // Stamp directory: one file per policy, touched after successful compilation.
    // Named per build variant so regular/draft/redact caches don't collide.
    const stamps_subdir = try std.fmt.allocPrint(alloc, ".pp-stamps-d{d}-r{d}", .{
        @intFromBool(config.is_draft),
        @intFromBool(config.redact),
    });
    defer alloc.free(stamps_subdir);
    const stamps_dir_path = try std.fs.path.join(alloc, &.{ output_path, stamps_subdir });
    defer alloc.free(stamps_dir_path);
    std.fs.cwd().makePath(stamps_dir_path) catch {}; // non-fatal if it fails

    // --- Collect policy files ---

    var file_paths = Array([]const u8){};
    defer {
        for (file_paths.items) |path| alloc.free(path);
        file_paths.deinit(alloc);
    }
    var skipped: usize = 0;
    while (walker.next() catch |err| {
        std.debug.print(
            "policypress: error while scanning policy directory: {s}\n",
            .{@errorName(err)},
        );
        return error.PolicyDirUnreadable;
    }) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".md")) {
            const base_name = std.fs.path.basename(entry.path);
            if (std.mem.eql(u8, base_name, "_index.md")) continue;
            const input_path = try std.fs.path.join(alloc, &.{ config.policy_dir, entry.path });
            if (stampIsNewer(input_path, stamps_dir_path, alloc)) {
                alloc.free(input_path);
                skipped += 1;
                continue;
            }
            try file_paths.append(alloc, input_path);
        }
    }

    const total_files = file_paths.items.len;
    if (total_files == 0) {
        if (skipped > 0) {
            std.debug.print("policypress: all {d} policies are up to date.\n", .{skipped});
        } else {
            std.debug.print("policypress: no .md files found in '{s}'\n", .{config.policy_dir});
        }
        return;
    }
    if (skipped > 0) {
        std.debug.print("policypress: {d} up to date, rebuilding {d}.\n", .{ skipped, total_files });
    }

    // --- Parallel compilation ---

    const root_progress = std.Progress.start(.{ .root_name = "PolicyPress" });
    const compile_node = root_progress.start("compiling policies", total_files);

    var error_mutex: std.Thread.Mutex = .{};
    var error_count: usize = 0;
    var error_list = std.ArrayList(ErrorInfo){};
    defer {
        for (error_list.items) |e| alloc.free(e.path);
        error_list.deinit(alloc);
    }

    var pool: std.Thread.Pool = undefined;
    pool.init(.{ .allocator = alloc }) catch |err| {
        std.debug.print(
            "policypress: failed to start thread pool: {s}\n",
            .{@errorName(err)},
        );
        compile_node.end();
        root_progress.end();
        return err;
    };
    defer pool.deinit();

    var wg: std.Thread.WaitGroup = .{};
    for (file_paths.items) |input_path| {
        pool.spawnWg(&wg, compileOne, .{
            alloc,
            config,
            input_path,
            stamps_dir_path,
            compile_node,
            &error_mutex,
            &error_count,
            &error_list,
        });
    }
    pool.waitAndWork(&wg);

    compile_node.end();
    root_progress.end();

    if (error_count > 0) {
        std.debug.print("\npolicypress: {d} of {d} policies failed:\n", .{ error_count, total_files });
        for (error_list.items) |e| {
            std.debug.print("  ✗ {s}\n    {s}\n", .{ e.path, describeCompileError(e.err) });
        }
        return error.CompilationFailed;
    }

    std.debug.print("\npolicypress: {d} policies compiled successfully.\n", .{total_files});
}

const ErrorInfo = struct {
    path: []const u8,
    err: anyerror,
};

fn printConfigError(config_path: []const u8, err: anyerror) void {
    switch (err) {
        error.InvalidTomlConfig => std.debug.print(
            "policypress: '{s}' is not valid TOML - check for syntax errors.\n",
            .{config_path},
        ),
        error.NoExtraInZolaConfig => std.debug.print(
            "policypress: '{s}' is missing an [extra] section.\n\nAdd:\n\n" ++
                "  [extra.policypress]\n  organization = \"…\"\n  logo         = \"logo.png\"\n" ++
                "  pdf_color    = \"#0e90f3\"\n  policy_dir   = \"policies/\"\n\n",
            .{config_path},
        ),
        error.NoPolicypressBlockInConfig => std.debug.print(
            "policypress: '{s}' is missing an [extra.policypress] block.\n\nAdd:\n\n" ++
                "  [extra.policypress]\n  organization = \"…\"\n  logo         = \"logo.png\"\n" ++
                "  pdf_color    = \"#0e90f3\"\n  policy_dir   = \"policies/\"\n\n",
            .{config_path},
        ),
        error.NoBaseUrlInZolaConfig => std.debug.print(
            "policypress: '{s}' is missing 'base_url'.\n" ++
                "Add:  base_url = \"https://security.example.com\"\n\n",
            .{config_path},
        ),
        error.NoLogoInExtra => std.debug.print(
            "policypress: '{s}' [extra.policypress] is missing 'logo'.\n" ++
                "Add:  logo = \"logo.png\"  (path relative to static/)\n\n",
            .{config_path},
        ),
        error.NoOrganizationInExtra => std.debug.print(
            "policypress: '{s}' [extra.policypress] is missing 'organization'.\n" ++
                "Add:  organization = \"Your Org Name\"\n\n",
            .{config_path},
        ),
        error.NoPDFColorInExtra => std.debug.print(
            "policypress: '{s}' [extra.policypress] is missing 'pdf_color'.\n" ++
                "Add:  pdf_color = \"#0e90f3\"  (any hex color)\n\n",
            .{config_path},
        ),
        else => std.debug.print(
            "policypress: failed to load '{s}': {s}\n",
            .{ config_path, @errorName(err) },
        ),
    }
}

fn describeCompileError(err: anyerror) []const u8 {
    return switch (err) {
        error.NoTitleInFrontMatter => "front matter is missing a 'title' field",
        error.InvalidTitleType => "front matter 'title' must be a string",
        error.NoLastReviewInFrontMatter => "front matter is missing 'extra.last_reviewed' (format: YYYY-MM-DD)",
        error.InvalidLastReviewedType => "front matter 'extra.last_reviewed' must be a string in YYYY-MM-DD format",
        error.NoRevisionsInFrontMatter => "front matter is missing 'extra.major_revisions' or the list is empty",
        error.InvalidRevisionsType => "front matter 'extra.major_revisions' must be a list",
        error.NoVersionForRevision => "a revision entry in 'extra.major_revisions' is missing the 'version' field",
        error.InvalidVersionType => "a revision 'version' value must be a string (e.g. \"1.0\")",
        error.InvalidRevisionFormat => "a revision entry in 'extra.major_revisions' is not a valid mapping",
        error.NoDateForRevision => "a revision entry is missing the 'date' field",
        error.NoApprovalForRevision => "a revision entry is missing the 'approved_by' field",
        error.NoDescriptionForRevision => "a revision entry is missing the 'description' field",
        error.InvalidShortCode => "a shortcode block ({% ... %}) is malformed - check for missing {% end %}",
        error.NoResourcePathDefined => "could not determine resource path from the file's location",
        error.PandocFailed => "pandoc exited with an error - check the output above for details",
        error.PandocNotFound => "pandoc was not found; make sure you are running inside the PolicyPress devshell (nix develop)",
        error.FileNotFound => "policy file was not found on disk (it may have been deleted mid-build)",
        error.OutOfMemory => "out of memory while processing this file",
        else => @errorName(err),
    };
}

// stampIsNewer and writeStamp live in utils so they can be unit-tested.
fn compileOne(
    alloc: Allocator,
    config: Config,
    input_path: []const u8,
    stamps_dir: []const u8,
    progress_node: std.Progress.Node,
    error_mutex: *std.Thread.Mutex,
    error_count: *usize,
    error_list: *std.ArrayList(ErrorInfo),
) void {
    defer progress_node.completeOne();

    const file_node = progress_node.start(std.fs.path.basename(input_path), 0);
    defer file_node.end();

    Pandoc.compile(alloc, config, input_path) catch |err| {
        error_mutex.lock();
        defer error_mutex.unlock();
        error_count.* += 1;
        error_list.append(alloc, .{
            .path = alloc.dupe(u8, input_path) catch input_path,
            .err = err,
        }) catch {};
        return;
    };

    writeStamp(alloc, stamps_dir, input_path);
}

// ---------------------------------------------------------------------------
// `policypress new <name>` — scaffold a new policy file
// ---------------------------------------------------------------------------

const new_usage =
    \\Usage: policypress new [--config <path>] <policy-name>
    \\
    \\  Scaffolds a new policy Markdown file with the required front matter.
    \\  The file is created at <policy_dir>/<slug>.md relative to the config.
    \\
    \\Options:
    \\  -c, --config <path>   Path to config.toml (default: config.toml)
    \\
    \\Examples:
    \\  policypress new 'Access Control'
    \\  policypress new incident-response --config my-config.toml
    \\
;

fn runNew(alloc: Allocator, args: []const [:0]u8) !void {
    var config_path: []const u8 = "config.toml";
    var policy_name: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--config") or std.mem.eql(u8, arg, "-c")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("policypress new: --config requires a value\n\n{s}", .{new_usage});
                std.process.exit(1);
            }
            config_path = args[i];
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            std.debug.print("{s}", .{new_usage});
            return;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("policypress new: unknown flag '{s}'\n\n{s}", .{ arg, new_usage });
            std.process.exit(1);
        } else {
            if (policy_name != null) {
                std.debug.print("policypress new: unexpected argument '{s}'\n\n{s}", .{ arg, new_usage });
                std.process.exit(1);
            }
            policy_name = arg;
        }
    }

    const name = policy_name orelse {
        std.debug.print("policypress new: policy name is required\n\n{s}", .{new_usage});
        std.process.exit(1);
    };

    const config_file = std.fs.cwd().openFile(config_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("policypress new: config file '{s}' not found\n", .{config_path});
        } else {
            std.debug.print("policypress new: cannot open '{s}': {s}\n", .{ config_path, @errorName(err) });
        }
        std.process.exit(1);
    };
    defer config_file.close();

    const contents = config_file.readToEndAlloc(alloc, 1024 * 1024) catch {
        std.debug.print("policypress new: failed to read '{s}'\n", .{config_path});
        std.process.exit(1);
    };
    defer alloc.free(contents);

    var config = Config.load(alloc, contents) catch |err| {
        printConfigError(config_path, err);
        std.process.exit(1);
    };
    defer config.deinit(alloc);

    const slug = try newSlugify(alloc, name);
    defer alloc.free(slug);

    if (slug.len == 0) {
        std.debug.print("policypress new: policy name '{s}' produces an empty slug\n", .{name});
        std.process.exit(1);
    }

    const filename = try std.fmt.allocPrint(alloc, "{s}.md", .{slug});
    defer alloc.free(filename);

    const output_path = try std.fs.path.join(alloc, &.{ config.policy_dir, filename });
    defer alloc.free(output_path);

    // Format today's date using the datetime library already wired into the binary.
    const now = dt.datetime.Datetime.now();
    const year = now.date.year;
    const month: u8 = now.date.month;
    const day: u8 = now.date.day;
    const date_str = try std.fmt.allocPrint(alloc, "{d:0>4}-{d:0>2}-{d:0>2}", .{ year, month, day });
    defer alloc.free(date_str);

    const content = try std.fmt.allocPrint(alloc,
        \\---
        \\title: "{s}"
        \\date: {s}
        \\description: ""
        \\draft: true
        \\extra:
        \\  last_reviewed: {s}
        \\  major_revisions:
        \\    - version: "0.1"
        \\      date: {s}
        \\      approved_by: ""
        \\      description: "Initial draft"
        \\---
        \\
        \\## Purpose
        \\
        \\## Scope
        \\
        \\## Policy
        \\
        \\## Exceptions
        \\
    , .{ name, date_str, date_str, date_str });
    defer alloc.free(content);

    // .exclusive = true fails atomically if the file already exists.
    const file = std.fs.cwd().createFile(output_path, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) {
            std.debug.print("policypress new: '{s}' already exists\n", .{output_path});
        } else {
            std.debug.print("policypress new: cannot create '{s}': {s}\n", .{ output_path, @errorName(err) });
        }
        std.process.exit(1);
    };
    defer file.close();

    try file.writeAll(content);
    std.debug.print("policypress: created {s}\n", .{output_path});
}

/// Converts a human-readable name to a URL-safe slug.
/// Runs of non-alphanumeric characters become a single hyphen.
/// Result is lowercased, with leading/trailing hyphens removed.
fn newSlugify(alloc: Allocator, name: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    defer result.deinit(alloc);

    var at_separator = true;
    for (name) |c| {
        if (std.ascii.isAlphanumeric(c)) {
            try result.append(alloc, std.ascii.toLower(c));
            at_separator = false;
        } else if (!at_separator) {
            try result.append(alloc, '-');
            at_separator = true;
        }
    }
    while (result.items.len > 0 and result.getLast() == '-') _ = result.pop();
    return result.toOwnedSlice(alloc);
}

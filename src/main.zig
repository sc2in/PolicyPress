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
const clap = @import("clap");
const Config = @import("config").Config;
const Reports = @import("reports");
const Pandoc = @import("pandoc");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-c, --config <str>     Path to config file. (default: config.toml)
        \\-i, --input  <str>     Path to input content directory. (default: content)
        \\-o, --output <str>     Path to output directory. (default: public)
        \\--draft                Add draft watermark to output (overrides config.toml).
        \\--no-draft             Do not add draft watermark to output (overrides config.toml).
        \\--redact               Redact content within redaction tags (overrides config.toml).
        \\--no-redact            Do not redact text within redaction tags (overrides config.toml).
        \\-v, --verbose          Enable verbose logging.
    );
    var buf: [128]u8 = undefined;
    // Report useful error and exit.
    var stderr = std.fs.File.stderr().writer(&buf).interface;
    defer stderr.flush() catch {};
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
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
    const config_path = if (res.args.config) |c| c else "config.toml";
    const config_file = std.fs.cwd().openFile(config_path, .{}) catch |err| {
        std.debug.print("Error opening config file '{s}': {}\n", .{ config_path, err });
        return err;
    };
    const contents = try config_file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(contents);

    var config = try Config.load(alloc, contents);
    defer config.deinit(alloc);

    if (res.args.draft != 0) {
        config.is_draft = true;
    }
    if (res.args.@"no-draft" != 0) {
        config.is_draft = false;
    }
    if (res.args.redact != 0) {
        config.redact = true;
    }
    if (res.args.@"no-redact" != 0) {
        config.redact = false;
    }

    //TODO: Verbosity
    // if (res.args.verbose != 0) {
    //     .log_level = .debug;
    // }
    std.log.debug("Running PolicyPress with configuration:\n{f}\n", .{config});

    var policy_dir = std.fs.cwd().openDir(config.policy_dir, .{
        .iterate = true,
        .access_sub_paths = true,
    }) catch |err| {
        std.debug.print("Error opening policy directory '{s}': {}\n", .{ config.policy_dir, err });
        return err;
    };
    defer policy_dir.close();
    var walker = try policy_dir.walk(alloc);
    defer walker.deinit();

    const output_path = if (res.args.output) |o| o else "public";
    config.build_dir = output_path;
    var output_dir = std.fs.cwd().openDir(output_path, .{ .access_sub_paths = true }) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Output directory '{s}' does not exist. Attempting to create it.\n", .{output_path});
            std.fs.cwd().makeDir(output_path) catch |mkdir_err| {
                std.debug.print("Error creating output directory '{s}': {}\n", .{ output_path, mkdir_err });
                return mkdir_err;
            };
            // Try opening the directory again after creating it
            return main();
        }
        std.debug.print("Error opening output directory '{s}': {}\n", .{ output_path, err });
        return err;
    };
    defer output_dir.close();

    var file_paths = Array([]const u8){};
    defer {
        for (file_paths.items) |path| alloc.free(path);
        file_paths.deinit(alloc);
    }
    while (try walker.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".md")) {
            const base_name = std.fs.path.basename(entry.path);
            if (std.mem.eql(u8, base_name, "_index.md")) continue;

            const input_path = try std.fs.path.join(alloc, &.{ config.policy_dir, entry.path });

            try file_paths.append(alloc, input_path);
        }
    }
    const total_files = file_paths.items.len;
    if (total_files == 0) {
        std.debug.print("No .md files found in '{s}'\n", .{config.policy_dir});
        return;
    }

    // -- Parallel Compilation --
    const root_progress = std.Progress.start(.{
        .root_name = "PolicyPress",
    });
    const compile_node = root_progress.start("compiling policies", total_files);

    // Thread-safe error tracking
    var error_mutex: std.Thread.Mutex = .{};
    var error_count: usize = 0;
    var error_list = std.ArrayList(ErrorInfo){};
    defer {
        for (error_list.items) |e| alloc.free(e.path);
        error_list.deinit(alloc);
    }

    // Initialize thread pool
    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = alloc });
    defer pool.deinit();

    var wg: std.Thread.WaitGroup = .{};

    // Spawn one task per file
    for (file_paths.items) |input_path| {
        pool.spawnWg(&wg, compileOne, .{
            alloc,
            config,
            input_path,
            compile_node,
            &error_mutex,
            &error_count,
            &error_list,
        });
    }

    // Main thread participates in work-stealing while waiting
    pool.waitAndWork(&wg);

    // Close the progress node (removes it from terminal)
    compile_node.end();
    root_progress.end();

    if (error_count > 0) {
        std.debug.print("\nPolicyPress completed with {d} error(s) out of {d} files:\n", .{
            error_count, total_files,
        });
        for (error_list.items) |e| {
            std.debug.print("  ✗ {s}: {}\n", .{ e.path, e.err });
        }
        return error.CompilationFailed;
    }

    std.debug.print("\nPolicyPress: {d} policies compiled successfully.\n", .{total_files});
}

const ErrorInfo = struct {
    path: []const u8,
    err: anyerror,
};

fn compileOne(
    alloc: Allocator,
    config: Config,
    input_path: []const u8,
    progress_node: std.Progress.Node,
    error_mutex: *std.Thread.Mutex,
    error_count: *usize,
    error_list: *std.ArrayList(ErrorInfo),
) void {
    defer progress_node.completeOne();

    // Per-file sub-node for granular progress
    const file_node = progress_node.start(std.fs.path.basename(input_path), 0);
    defer file_node.end();

    Pandoc.compile(
        alloc,
        config,
        input_path,
    ) catch |err| {
        error_mutex.lock();
        defer error_mutex.unlock();
        error_count.* += 1;
        error_list.append(alloc, .{
            .path = alloc.dupe(u8, input_path) catch input_path,
            .err = err,
        }) catch {};
        return;
    };
}

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
        \\--no-draft             Do not add draft watermark to output.
        \\--no-redact            Do not redact text within redaction tags in output.
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

    const output_path = if (res.args.config) |c| c else "public";

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

    //     while (try walker.next()) |entry| {
    //         if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".md")) {
    //             const base_name = std.fs.path.basename(entry.path);
    //             if (std.mem.eql(u8, base_name, "_index.md")) continue;

    //             const input_path = b.pathJoin(&.{ "content", "policies", entry.path });
    //             const input = b.path(input_path);

    //             // Step 2: Run pandoc wrapper
    //             const run_wrapper = b.addRunArtifact(pandoc_sh);
    //             run_wrapper.addArg("--input");
    //             run_wrapper.addFileArg(input);
    //             run_wrapper.addArg("--output");
    //             run_wrapper.expectExitCode(0);
    //             _ = run_wrapper.captureStdErr();
    //             const pdf_dir = run_wrapper.addOutputDirectoryArg(base_name);
    //             if (draft_option) run_wrapper.addArg("-d");
    //             if (redact_option) run_wrapper.addArg("-r");

    //             const inst = b.addInstallDirectory(.{
    //                 .install_dir = .prefix,
    //                 .source_dir = pdf_dir,

    //                 .install_subdir = "pdfs",
    //             });
    //             inst.step.dependOn(&run_wrapper.step);
    //             pdf_step.dependOn(&inst.step);
    //             // Step 3: Install the generated PDF
    //             _ = wf.addCopyDirectory(
    //                 pdf_dir.path(b, ""),
    //                 "", //b.pathJoin(&.{ base_name, base_name }),
    //                 .{ .include_extensions = &.{"pdf"} },
    //             );
    //         }
    //     }
}

//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: AGPL-3.0-or-later
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const ReportType = @import("src/control_report.zig").Report;

pub fn build(b: *std.Build) !void {
    const draft_option = b.option(bool, "draft", "Produce pdfs with a draft watermark") orelse false;
    // const redact_option = b.option(bool, "redact", "Produce pdfs with redacted information") orelse false;
    // const report_option = b.option(ReportType, "report", "Type of report to run") orelse .SCF;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tomlz = b.dependency("tomlz", .{
        .target = target,
        .optimize = optimize,
    });

    const yaml = b.dependency("yaml", .{
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const mvzr = b.dependency("mvzr", .{
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const pg = b.dependency("datetime", .{
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const tera_mod = b.addModule("tera", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/tera/tera.zig"),
    });

    const frontmatter_mod = b.addModule("frontmatter", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/frontmatter.zig"),
    });
    frontmatter_mod.addImport("yaml", yaml.module("yaml"));
    frontmatter_mod.addImport("tomlz", tomlz.module("tomlz"));
    const config_mod = b.addModule("config_parser", .{
        .root_source_file = b.path("src/config.zig"),
        .target = target,
        .optimize = optimize,
    });
    config_mod.addImport("datetime", pg.module("datetime"));
    config_mod.addImport("FM", frontmatter_mod);

    const utils_mod = b.addModule("utils", .{
        .root_source_file = b.path("src/utils.zig"),
        .target = target,
        .optimize = optimize,
    });
    utils_mod.addImport("FM", frontmatter_mod);
    utils_mod.addImport("mvzr", mvzr.module("mvzr"));
    utils_mod.addImport("yaml", yaml.module("yaml"));
    utils_mod.addImport("tomlz", tomlz.module("tomlz"));

    var pandoc_sh: *std.Build.Step.Compile = undefined;

    // the executable from your call to exe_mod.addExecutable
    if (target.result.os.tag != .windows) {
        const zap = b.dependency("zap", .{
            .target = target,
            .optimize = optimize,
            .openssl = false, // set to true to enable TLS support
        });
        const server_mod = b.addModule("server", .{
            .root_source_file = b.path("src/server.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        });
        server_mod.addImport("zap", zap.module("zap"));
        server_mod.addImport("clap", clap.module("clap"));
        const server = b.addExecutable(.{
            .name = "http",
            .root_module = server_mod,
        });

        const run_server = b.addRunArtifact(server);
        if (b.args) |args| {
            run_server.addArgs(args);
        }

        const serve_step = b.step("preview", "Serve the zola output");
        serve_step.dependOn(&run_server.step);
    } else {
        _ = b.step("preview", "Serve the zola output (Not available on Windows. run `zola preview` instead.)");
    }

    const pandoc_sh_mod = b.addModule("pandocsh", .{
        .root_source_file = b.path("src/pandoc.zig"),
        .target = target,
        .optimize = optimize,
    });
    pandoc_sh_mod.addImport("tera", tera_mod);
    pandoc_sh_mod.addImport("FM", frontmatter_mod);
    pandoc_sh_mod.addImport("mvzr", mvzr.module("mvzr"));
    pandoc_sh_mod.addImport("datetime", pg.module("datetime"));
    pandoc_sh_mod.addImport("config", config_mod);
    pandoc_sh_mod.addImport("utils", utils_mod);
    pandoc_sh = b.addExecutable(.{
        .root_module = pandoc_sh_mod,
        .name = "pandoc_sh",
    });

    var pandoc_step = b.step("pdf", "run pandoc.sh");
    const pandoc_exe = b.addRunArtifact(pandoc_sh);
    if (b.args) |args| {
        pandoc_exe.addArgs(args);
    }

    pandoc_step.dependOn(&pandoc_exe.step);

    const reports_mod = b.addModule("policy_report", .{
        .target = target,
        .optimize = .ReleaseFast,
        .root_source_file = b.path("src/control_report.zig"),
    });
    reports_mod.addImport("clap", clap.module("clap"));
    reports_mod.addImport("yaml", yaml.module("yaml"));
    reports_mod.addImport("tomlz", tomlz.module("tomlz"));
    reports_mod.addImport("datetime", pg.module("datetime"));
    reports_mod.addImport("config", config_mod);
    reports_mod.addImport("FM", frontmatter_mod);

    const policypress_mod = b.addModule("policypress", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });
    policypress_mod.addImport("clap", clap.module("clap"));
    policypress_mod.addImport("config", config_mod);
    policypress_mod.addImport("pandoc", pandoc_sh_mod);
    policypress_mod.addImport("reports", reports_mod);
    const policypress_exe = b.addExecutable(.{
        .root_module = policypress_mod,
        .name = "policypress",
    });
    const run_policypress = b.addRunArtifact(policypress_exe);
    if (b.args) |args| {
        run_policypress.addArgs(args);
    }
    b.installArtifact(policypress_exe);
    b.default_step.dependOn(&policypress_exe.step);

    const run_step = b.step("run", "Run Policy Center");
    run_step.dependOn(&run_policypress.step);

    {
        const docs_step = b.step("docs", "Build Documentation");
        const docs_install = b.addInstallDirectory(.{
            .install_dir = .prefix,
            .install_subdir = "docs",
            .source_dir = pandoc_sh.getEmittedDocs(),
        });
        docs_step.dependOn(&docs_install.step);
    }
    {
        const test_module = b.addModule("test", .{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        test_module.addImport("FM", frontmatter_mod);
        test_module.addImport("utils", utils_mod);
        test_module.addImport("pandoc", pandoc_sh_mod);
        test_module.addImport("config", config_mod);
        test_module.addImport("reports", reports_mod);
        test_module.addImport("datetime", pg.module("datetime"));
        test_module.addImport("mvzr", mvzr.module("mvzr"));
        const unit_tests = b.addTest(.{
            .root_module = test_module,
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_unit_tests.step);
    }
    {
        const web_build = b.addSystemCommand(&.{
            "zola",
            "build",
            "--force",
        });
        if (draft_option) web_build.addArg("--drafts");
        if (optimize != .Debug) web_build.addArg("--minify") else web_build.addArg("--base-url=http://127.0.0.1:1111/");
        web_build.addArg("-o");
        const web_output = web_build.addOutputDirectoryArg("public");
        const web_inst = b.addInstallDirectory(.{
            .install_dir = .prefix,
            .source_dir = web_output,
            .install_subdir = "public",
        });
        const web_step = b.step("web", "Build website from zola");
        web_step.dependOn(&web_inst.step);
        b.default_step.dependOn(web_step);
    }
    // {
    //     const pdf_step = b.step("pdfs", "Build pdfs directly from the build script");

    //     const wf = b.addWriteFiles();

    //     // const config = try @import("src/config.zig").BuildConfig.load_config_toml(b.allocator);

    //     // const conf = config;

    //     var dir = try std.fs.cwd().openDir(b.pathJoin(&.{ "content", "policies" }), .{
    //         .iterate = true,
    //         .access_sub_paths = true,
    //     });
    //     defer dir.close();

    //     var walker = try dir.walk(b.allocator);
    //     defer walker.deinit();

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

    //     const mkdir = b.addInstallDirectory(.{
    //         .install_dir = .prefix,
    //         .install_subdir = "pdfs",
    //         .source_dir = wf.getDirectory(),
    //         .include_extensions = &.{"pdf"},
    //     });
    //     pdf_step.dependOn(&mkdir.step);

    //     // b.default_step.dependOn(report_step);
    //     b.default_step.dependOn(pdf_step);
    // }
}

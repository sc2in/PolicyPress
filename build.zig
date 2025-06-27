const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;

const year = "2025";
const org = "SC2";
const logo = "static/logo.png";
const color = "AACEFF";
var is_draft = false;
var is_redact = false;

pub fn build(b: *std.Build) !void {
    const draft_option = b.option(bool, "draft", "Produce pdfs with a draft watermark") orelse false;
    is_draft = draft_option;
    const redact_option = b.option(bool, "redact", "Produce pdfs with redacted information") orelse false;
    is_redact = redact_option;
    const policy_dir = "content/policies";

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tomlz = b.dependency("tomlz", .{
        .target = target,
        .optimize = optimize,
    });
    const yaml = b.dependency("yaml", .{
        .target = target,
        .optimize = optimize,
    });
    const mvzr = b.dependency("mvzr", .{
        .target = target,
        .optimize = optimize,
    });
    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });
    const tera_mod = b.addModule("tera", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/tera/tera.zig"),
    });
    const pg = b.dependency("datetime", .{
        .target = target,
        .optimize = optimize,
    });

    const web_build = b.addSystemCommand(&.{
        "zola",
        "build",
        "--force",
    });
    if (draft_option) web_build.addArg("--drafts");
    if (optimize != .Debug) web_build.addArg("--minify");
    web_build.addArg("-o");
    const web_output = web_build.addOutputDirectoryArg("public");
    const web_inst = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .source_dir = web_output,
        .install_subdir = "public",
    });
    const web_step = b.step("web", "Build website from zola");
    web_step.dependOn(&web_inst.step);

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
    // the executable from your call to b.addExecutable(...)

    const pandoc_sh_mod = b.addModule("pandocsh", .{
        .root_source_file = b.path("src/pandoc.zig"),
        .target = target,
        .optimize = optimize,
    });
    pandoc_sh_mod.addImport("tomlz", tomlz.module("tomlz"));
    pandoc_sh_mod.addImport("yaml", yaml.module("yaml"));
    pandoc_sh_mod.addImport("mvzr", mvzr.module("mvzr"));
    pandoc_sh_mod.addImport("clap", clap.module("clap"));
    pandoc_sh_mod.addImport("tera", tera_mod);
    pandoc_sh_mod.addImport("datetime", pg.module("datetime"));
    const pandoc_sh = b.addExecutable(.{
        .root_module = pandoc_sh_mod,
        .name = "pandoc_sh",
    });

    var pandoc_step = b.step("pdf", "run pandoc.sh");
    const pandoc_exe = b.addRunArtifact(pandoc_sh);
    if (b.args) |args| {
        pandoc_exe.addArgs(args);
    }

    pandoc_step.dependOn(&pandoc_exe.step);

    const docs_step = b.step("docs", "Build Documentation");
    const docs_install = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = pandoc_sh.getEmittedDocs(),
    });
    docs_step.dependOn(&docs_install.step);

    const test_module = b.addModule("test", .{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_module.addImport("tomlz", tomlz.module("tomlz"));
    test_module.addImport("yaml", yaml.module("yaml"));
    test_module.addImport("mvzr", mvzr.module("mvzr"));

    const policy_report = b.addExecutable(.{
        .name = "policy_report",
        .target = target,
        .optimize = .ReleaseFast,
        .root_source_file = b.path("src/control_report.zig"),
    });
    policy_report.root_module.addImport("clap", clap.module("clap"));
    policy_report.root_module.addImport("yaml", yaml.module("yaml"));
    policy_report.root_module.addImport("tomlz", tomlz.module("tomlz"));

    const run_policy_report = b.addRunArtifact(policy_report);
    run_policy_report.addArg("--controls_file");
    run_policy_report.addFileArg(b.path("templates/opencontrols/standards/SCF.json"));
    run_policy_report.addArg("--policy_root");
    run_policy_report.addDirectoryArg(b.path(policy_dir));
    const policy_report_output = run_policy_report.captureStdOut();
    const policy_report_inst = b.addInstallFileWithDir(
        policy_report_output,
        .prefix,
        "policy_report.json",
    );

    const report_step = b.step("reports", "Run reports");
    report_step.dependOn(&policy_report_inst.step);

    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const pdf_step = b.step("pdfs", "Build pdfs directly from the build script");

    const wf = b.addWriteFiles();

    var dir = try std.fs.cwd().openDir(policy_dir, .{
        .iterate = true,
        .access_sub_paths = true,
    });
    defer dir.close();

    var walker = try dir.walk(b.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".md")) {
            const base_name = std.fs.path.basename(entry.path);
            if (std.mem.eql(u8, base_name, "_index.md")) continue;

            const input_path = b.pathJoin(&.{ policy_dir, entry.path });
            const input = b.path(input_path);

            // Step 2: Run pandoc wrapper
            const run_wrapper = b.addRunArtifact(pandoc_sh);
            run_wrapper.addArgs(&.{
                "--color", "FFFFFF",
                "--org",   "SC2",
                "--root",  "./",
            });
            run_wrapper.addArg("--logo");
            run_wrapper.addFileArg(b.path("static/logo.png"));
            run_wrapper.addArg("--input");
            run_wrapper.addFileArg(input);
            run_wrapper.addArg("--output");
            run_wrapper.expectExitCode(0);
            _ = run_wrapper.captureStdErr();
            const pdf_dir = run_wrapper.addOutputDirectoryArg(base_name);
            if (is_draft) run_wrapper.addArg("-d");
            if (is_redact) run_wrapper.addArg("-r");

            const inst = b.addInstallDirectory(.{
                .install_dir = .prefix,
                .source_dir = pdf_dir,

                .install_subdir = "pdfs",
            });
            pdf_step.dependOn(&inst.step);
            inst.step.dependOn(&run_wrapper.step);
            // Step 3: Install the generated PDF
            _ = wf.addCopyDirectory(
                pdf_dir.path(b, ""),
                "", //b.pathJoin(&.{ base_name, base_name }),
                .{ .include_extensions = &.{"pdf"} },
            );
        }
    }

    const mkdir = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "pdfs",
        .source_dir = wf.getDirectory(),
        .include_extensions = &.{"pdf"},
    });
    pdf_step.dependOn(&mkdir.step);

    b.default_step.dependOn(report_step);
    b.default_step.dependOn(pdf_step);
    b.default_step.dependOn(web_step);
}

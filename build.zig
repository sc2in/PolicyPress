//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: AGPL-3.0-or-later
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const ReportType = @import("src/control_report.zig").Report;

pub fn build(b: *std.Build) !void {
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
        var docs_step = b.step("docs", "Build Documentation");
        const docs_install = b.addInstallDirectory(.{
            .install_dir = .prefix,
            .install_subdir = "docs",
            .source_dir = policypress_exe.getEmittedDocs(),
        });
        docs_step.dependOn(&docs_install.step);
        b.default_step.dependOn(docs_step);
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
}

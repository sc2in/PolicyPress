//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;

const ReportType = @import("src/control_report.zig").Report;

pub fn build(b: *std.Build) !void {
    var threaded: std.Io.Threaded = .init(b.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const target = b.standardTargetOptions(.{
        .default_target = defaultTarget(io),
    });
    const optimize = b.standardOptimizeOption(.{});

    const tomlz = b.dependency("tomlz", .{
        .target = target,
        .optimize = optimize,
    });

    const mvzr = b.dependency("mvzr", .{
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = .ReleaseSafe,
    });
    // const zetta_dep = b.dependency("zetta", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const zetta_mod = zetta_dep.module("zetta");

    const zigmark_dep = b.dependency("zigmark", .{
        .target = target,
        .optimize = optimize,
    });
    const zigmark_mod = zigmark_dep.module("zigmark");

    const pozeiden_dep = b.dependency("pozeiden", .{
        .target = target,
        .optimize = optimize,
    });
    const pozeiden_mod = pozeiden_dep.module("pozeiden");

    const config_mod = b.addModule("config_parser", .{
        .root_source_file = b.path("src/config.zig"),
        .target = target,
        .optimize = optimize,
    });
    config_mod.addImport("tomlz", tomlz.module("tomlz"));
    config_mod.addImport("zigmark", zigmark_mod);

    const utils_mod = b.addModule("utils", .{
        .root_source_file = b.path("src/utils.zig"),
        .target = target,
        .optimize = optimize,
    });
    utils_mod.addImport("mvzr", mvzr.module("mvzr"));
    utils_mod.addImport("zigmark", zigmark_mod);

    // config uses utils for Date/today and readAllAlloc helpers.
    config_mod.addImport("utils", utils_mod);

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

    // Typst PDF engine: markdown → zigmark → Typst markup (mermaid via
    // pozeiden) → `typst compile`.
    const typst_mod = b.addModule("typst_engine", .{
        .root_source_file = b.path("src/typst.zig"),
        .target = target,
        .optimize = optimize,
    });
    typst_mod.addImport("clap", clap.module("clap"));
    typst_mod.addImport("config", config_mod);
    typst_mod.addImport("utils", utils_mod);
    typst_mod.addImport("zigmark", zigmark_mod);
    typst_mod.addImport("pozeiden", pozeiden_mod);
    const typst_exe = b.addExecutable(.{
        .root_module = typst_mod,
        .name = "pdf_engine",
    });

    const pdf_step = b.step("pdf", "Compile a single policy to PDF via the typst engine");
    const pdf_run = b.addRunArtifact(typst_exe);
    if (b.args) |args| {
        pdf_run.addArgs(args);
    }
    pdf_step.dependOn(&pdf_run.step);

    const reports_mod = b.addModule("policy_report", .{
        .target = target,
        .optimize = .ReleaseFast,
        .root_source_file = b.path("src/control_report.zig"),
    });
    reports_mod.addImport("clap", clap.module("clap"));
    reports_mod.addImport("tomlz", tomlz.module("tomlz"));
    reports_mod.addImport("config", config_mod);
    reports_mod.addImport("zigmark", zigmark_mod);

    const policypress_mod = b.addModule("policypress", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });
    const build_opts = b.addOptions();
    build_opts.addOption([]const u8, "install_prefix", b.install_prefix);
    policypress_mod.addImport("build_options", build_opts.createModule());
    policypress_mod.addImport("clap", clap.module("clap"));
    policypress_mod.addImport("config", config_mod);
    policypress_mod.addImport("typst", typst_mod);
    policypress_mod.addImport("reports", reports_mod);
    policypress_mod.addImport("utils", utils_mod);
    // Build-time mermaid rendering for the site (src/diagrams.zig, `render-diagrams`).
    policypress_mod.addImport("pozeiden", pozeiden_mod);
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
        test_module.addImport("zigmark", zigmark_mod);
        test_module.addImport("utils", utils_mod);
        test_module.addImport("typst", typst_mod);
        test_module.addImport("config", config_mod);
        test_module.addImport("reports", reports_mod);
        test_module.addImport("mvzr", mvzr.module("mvzr"));
        // src/diagrams.zig (imported by src/test.zig) renders mermaid via pozeiden.
        test_module.addImport("pozeiden", pozeiden_mod);
        const unit_tests = b.addTest(.{
            .root_module = test_module,
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);
        run_unit_tests.setCwd(b.path("."));
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_unit_tests.step);
    }
    {
        // Fuzz harness for PolicyPress's own surfaces (src/fuzz.zig).
        //   zig build fuzz          — run each target once (smoke test)
        //   zig build fuzz --fuzz   — coverage-guided fuzzing
        const fuzz_module = b.addModule("fuzz", .{
            .root_source_file = b.path("src/fuzz.zig"),
            .target = target,
            .optimize = .Debug,
        });
        fuzz_module.addImport("config", config_mod);
        fuzz_module.addImport("utils", utils_mod);
        fuzz_module.addImport("zigmark", zigmark_mod);
        fuzz_module.addImport("tomlz", tomlz.module("tomlz"));
        const fuzz_tests = b.addTest(.{
            .root_module = fuzz_module,
            // The self-hosted backend omits sanitizer-coverage sections,
            // leaving the pcs array empty and panicking in Build/Fuzz.zig.
            // LLVM emits the required __sancov_pcs1/__sancov_cntrs sections.
            .use_llvm = true,
        });
        const run_fuzz = b.addRunArtifact(fuzz_tests);
        const fuzz_step = b.step("fuzz", "Run fuzz tests (append --fuzz for coverage-guided fuzzing)");
        fuzz_step.dependOn(&run_fuzz.step);
    }
    {
        // `zig build check` - semantic analysis without emitting a binary.
        // Used by ZLS for IDE diagnostics and as a fast CI sanity check.
        const check_step = b.step("check", "Semantic analysis (no binary emitted, used by ZLS)");
        check_step.dependOn(&policypress_exe.step);
        check_step.dependOn(&typst_exe.step);
    }
    {
        // E2E test: run policypress against the starter/ template, mirroring
        // what action.yml does for real consumers.  Requires typst in PATH
        // (provided by the devshell / Nix flake check environment).
        const e2e_step = b.step("e2e", "Run end-to-end test against starter/");

        // Step 1: ensure starter/static/logo.png exists (required by config.toml).
        const copy_template = b.addSystemCommand(&.{
            "bash", "-c",
            "mkdir -p starter/static && " ++
                "{ cp -f static/logo.png starter/static/logo.png 2>/dev/null || " ++
                "touch starter/static/logo.png; }",
        });
        copy_template.setCwd(b.path("."));

        // Step 2: run policypress from starter/ - same working dir as a real consumer.
        const e2e_run = b.addRunArtifact(policypress_exe);
        e2e_run.addArgs(&.{
            "--config", "config.toml",
            "--output", "public/pdfs",
        });
        e2e_run.setCwd(b.path("starter"));
        e2e_run.step.dependOn(&copy_template.step);
        e2e_step.dependOn(&e2e_run.step);
    }
}

/// On NixOS there is no standard FHS layout, so Zig's native target detection
/// probes many non-existent paths which is slow. Detect NixOS and return an
/// explicit target query to skip the probing.
fn defaultTarget(io: std.Io) std.Target.Query {
    if (std.Io.Dir.accessAbsolute(io, "/etc/NIXOS", .{})) |_| {
        return .{
            .os_tag = .linux,
            .abi = .gnu,
        };
    } else |_| {}
    return .{};
}

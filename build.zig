const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;

pub fn build(b: *std.Build) !void {
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
    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false, // set to true to enable TLS support
    });
    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
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

    // the executable from your call to b.addExecutable(...)

    const pandoc_sh_mod = b.addModule("pandocsh", .{
        .root_source_file = b.path("src/pandoc.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    pandoc_sh_mod.addImport("tomlz", tomlz.module("tomlz"));
    pandoc_sh_mod.addImport("yaml", yaml.module("yaml"));
    pandoc_sh_mod.addImport("mvzr", mvzr.module("mvzr"));
    pandoc_sh_mod.addImport("clap", clap.module("clap"));
    const exe = b.addExecutable(.{
        .root_module = pandoc_sh_mod,
        .name = "pandoc_sh",
    });
    b.installArtifact(exe);
    const pandoc_step = b.step("pdf", "run pandoc.sh");
    const pandoc_exe = b.addRunArtifact(exe);
    if (b.args) |args| {
        pandoc_exe.addArgs(args);
    }

    pandoc_step.dependOn(&pandoc_exe.step);

    const docs_step = b.step("docs", "Build Documentation");
    const docs_install = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = exe.getEmittedDocs(),
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

    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const run_server = b.addRunArtifact(server);
    if (b.args) |args| {
        run_server.addArgs(args);
    }

    const serve_step = b.step("serve", "Serve the zola output");
    serve_step.dependOn(&run_server.step);
}

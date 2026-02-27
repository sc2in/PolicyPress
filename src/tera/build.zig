//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: AGPL-3.0-or-later
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "tera-interpreter",
        .root_source_file = b.path("./tera.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Tera interpreter");
    run_step.dependOn(&run_cmd.step);

    const example_exe = b.addExecutable(.{
        .name = "examples",
        .root_source_file = b.path("./example.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_exe.root_module.addAnonymousImport("frontmatter", .{
        .root_source_file = b.path("../frontmatter.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Run command
    const example_run_cmd = b.addRunArtifact(example_exe);
    example_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        example_run_cmd.addArgs(args);
    }

    const example_run_step = b.step("example", "Run the Tera examples");
    example_run_step.dependOn(&example_run_cmd.step);

    // Tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("./tera.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Additional test targets for individual modules
    const modules = [_][]const u8{ "lexer", "parser", "context", "renderer", "filters" };

    for (modules) |module| {
        const module_test = b.addTest(.{
            .name = std.fmt.allocPrint(b.allocator, "test-{s}", .{module}) catch @panic("OOM"),
            .root_source_file = b.path(std.fmt.allocPrint(b.allocator, "{s}.zig", .{module}) catch @panic("OOM")),
            .target = target,
            .optimize = optimize,
        });

        const run_module_test = b.addRunArtifact(module_test);

        const module_test_step = b.step(std.fmt.allocPrint(b.allocator, "test-{s}", .{module}) catch @panic("OOM"), std.fmt.allocPrint(b.allocator, "Run {s} module tests", .{module}) catch @panic("OOM"));
        module_test_step.dependOn(&run_module_test.step);
    }
}

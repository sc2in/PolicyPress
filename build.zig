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

    const pandoc_sh_mod = b.addModule("pandocsh", .{
        .root_source_file = b.path("src/pandoc.zig"),
        .target = target,
        .optimize = optimize,
    });
    pandoc_sh_mod.addImport("tomlz", tomlz.module("tomlz"));
    const exe = b.addExecutable(.{
        .root_module = pandoc_sh_mod,
        .name = "pandoc_sh",
    });
    b.installArtifact(exe);
    const run_step = b.step("run", "run pandoc.sh");
    const run_exe = b.addRunArtifact(exe);
    run_step.dependOn(&run_exe.step);
}

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

pub fn build(b: *std.Build) !void {
    const draft_option = b.option(bool, "draft", "Produce pdfs with a draft watermark") orelse false;
    is_draft = draft_option;

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

        const serve_step = b.step("serve", "Serve the zola output");
        serve_step.dependOn(&run_server.step);
    } else {
        _ = b.step("serve", "Serve the zola output (Not available on Windows. Does nothing.)");
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
    const exe = b.addExecutable(.{
        .root_module = pandoc_sh_mod,
        .name = "pandoc_sh",
    });
    b.installArtifact(exe);
    var pandoc_step = b.step("pdf", "run pandoc.sh");
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

    // const web_step = b.step("web", "Build the policy center");
    // web_step.makeFn = build_web;
    // web_step.dependOn(pandoc_step);
    const pdf_step = b.step("pdfs", "Build pdfs directly from the build script");
    try build_pdfs(b, pdf_step, exe);
}

const MyStep = struct {
    step: std.Build.Step,
    my_option: bool,
};
fn build_web(step: *std.Build.Step, opt: std.Build.Step.MakeOptions) !void {
    const p = opt.progress_node.start("Build web", 2);
    defer p.end();
    const b = step.owner;

    const web = b.addWriteFiles();
    b.installDirectory(.{
        .install_dir = .prefix,
        .source_dir = web.addCopyDirectory(b.path("public/pdf"), "pdf", .{}),
        .install_subdir = "web/pdf",
    });

    const zp = p.start("Zola build", 1);
    _ = b.run(&.{ "zola", "build" });
    zp.end();

    const ip = p.start("Copy web artifacts", 1);
    defer ip.end();
    b.installDirectory(.{
        .install_dir = .prefix,
        .source_dir = web.addCopyDirectory(b.path("public/"), "", .{}),
        .install_subdir = "web",
    });
}

fn build_pdfs(b: *std.Build, step: *std.Build.Step, exe: *std.Build.Step.Compile) !void {
    // const website = b.addWriteFiles();

    const markdown_files = b.run(&.{ "git", "ls-files", "content/policies/*.md" });
    var lines = std.mem.tokenizeScalar(u8, markdown_files, '\n');

    std.fs.cwd().makeDir(".tmp") catch |e| {
        if (e != error.PathAlreadyExists) return e;
    };

    const inst = b.addInstallDirectory(.{
        .source_dir = b.path(".tmp"),
        .install_dir = .prefix,
        .install_subdir = "pdfs",
        .include_extensions = &.{"pdf"},
    });

    while (lines.next()) |file_path| {
        if (std.mem.endsWith(u8, file_path, "_index.md")) continue;

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.addArgs(&.{
            "--color", "FFFFFF",
            "--logo",  "static/logo.png",
            "--org",   "SC2",
            "-i",      file_path,
            "-o",      ".tmp",
            "--root",  "./",
        });
        if (is_draft) run_cmd.addArg("-d");

        inst.step.dependOn(&run_cmd.step);
        step.dependOn(&run_cmd.step);
    }

    step.dependOn(&inst.step);
}
fn cut_prefix(text: []const u8, prefix: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, text, prefix)) return text[prefix.len..];
    return null;
}

fn cut_suffix(text: []const u8, suffix: []const u8) ?[]const u8 {
    if (std.mem.endsWith(u8, text, suffix)) return text[0 .. text.len - suffix.len];
    return null;
}
fn build_pdf_from_markdown(b: *std.Build, path: std.Build.LazyPath, step: *std.Build.Step) !std.Build.LazyPath {
    const title = b.fmt("Run pandoc for {s}", .{cut_prefix(path.getDisplayName(), "content/policies/").?});
    const res_path = b.fmt("--resource-path={s}", .{path.dirname().getPath(b)});
    const data_path = b.fmt("--data-dir={s}", .{try std.fs.cwd().realpathAlloc(b.allocator, ".")});
    const header = b.fmt("header-right=\\includegraphics[width=2cm,height=2cm]{{{s}}}", .{logo});
    const footer = b.fmt("footer-left={s} \\textcopyright {s}", .{ org, year });
    const title_logo = b.fmt("titlepage-logo={s}", .{logo});
    const inst = b.fmt("institution=\"{s}\"", .{org});
    const col = b.fmt("titlepage-rule-color={s}", .{color});

    const contents = try readLazyPathToMemory(b, path);
    const str = Array(u8){
        .allocator = b.allocator,
        .items = contents,
        .capacity = contents.len,
    };
    // defer str.deinit();
    // std.debug.print("{any}\n", .{std.unicode.utf8ValidateSlice(str.items)});

    const pandoc_step = std.Build.Step.Run.create(b, title);
    step.dependOn(&pandoc_step.step);
    // try u.replace_org(&str, org, u.DummyProgress{});
    // try u.replace_mermaid(&str, u.DummyProgress{});
    pandoc_step.setStdIn(.{ .bytes = str.items });

    pandoc_step.addArg("pandoc");
    pandoc_step.addPathDir(".devbox/nix/profile/default/bin/");
    pandoc_step.addArgs(&.{ "-V", "footer-center=Confidental" });
    pandoc_step.addArgs(&.{ "-V", header });
    pandoc_step.addArgs(&.{ "-V", footer });
    pandoc_step.addArgs(&.{ "-V", title_logo });
    pandoc_step.addArgs(&.{ "-V", inst });
    pandoc_step.addArgs(&.{ "-V", col });
    pandoc_step.addArgs(&.{ "-V", "papersize=letter" });
    pandoc_step.addArgs(&.{ "-V", "titlepage=true" });
    pandoc_step.addArgs(&.{ "-V", "toc=true" });
    pandoc_step.addArgs(&.{ "-V", "toc-own-page=true" });
    pandoc_step.addArgs(&.{ "-V", "toc-depth=3" });
    pandoc_step.addArgs(&.{ "-V", "logo-width=6cm" });
    pandoc_step.addArgs(&.{ "-V", "table-use-row-colors=true" });
    pandoc_step.addArgs(&.{ "-F", "mermaid-filter" });
    pandoc_step.addArgs(&.{ "--template", "eisvogel" });
    pandoc_step.addArgs(&.{
        res_path,
        data_path,
        "--from=markdown",
        "--to=pdf",
        "--webtex",
        "--listings",
        "--pdf-engine=xelatex",
    });
    if (is_draft) {
        pandoc_step.addArgs(&.{ "-V", "page-background=static/draft.png" });
        pandoc_step.addArgs(&.{ "-V", "page-background-opacity=0.8" });
    }
    // pandoc_step.addFileArg(path);

    return pandoc_step.captureStdOut();
}
pub fn readLazyPathToMemory(
    b: *std.Build,
    lazy_path: std.Build.LazyPath,
) ![]u8 {

    // Open and read the file as usual
    var file = try std.fs.cwd().openFile(lazy_path.getPath(b), .{});
    defer file.close();

    return try file.readToEndAlloc(b.allocator, 100_000_000);
}

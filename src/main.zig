//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//!
//! This program automates the process of converting Markdown policy documents into styled PDF files.
//! It loads configuration from a TOML file, processes Markdown files (including YAML front matter and custom placeholders),
//! applies organization branding, renders the markdown to Typst markup in-process (zigmark; mermaid
//! diagrams via pozeiden), and invokes `typst compile` to generate PDFs.
//! The build is highly configurable, supporting custom logos, organization names, color extraction from images,
//! and options for draft/redacted document states. The system is designed for batch processing of policy directories,
//! with robust error handling and logging at multiple stages of the pipeline.
const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const EnvMap = std.process.Environ.Map;
const build_options = @import("build_options");

const clap = @import("clap");
const Config = @import("config").Config;
const Date = @import("utils").Date;
const stampIsNewer = @import("utils").stampIsNewer;
const isDraftPolicy = @import("utils").isDraftPolicy;
const Typst = @import("typst");
const reports = @import("reports");
const writeStamp = @import("utils").writeStamp;
const audit = @import("audit.zig");
const diagrams = @import("diagrams.zig");
const controls = @import("controls");
const control_annex = @import("control_annex");
const zigmark = @import("zigmark");

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------

pub var pp_log_level: std.log.Level = .info;
pub var pp_json_log: bool = false;

pub const std_options: std.Options = .{
    .log_level = .debug, // runtime-filtered in ppLog
    .logFn = ppLog,
};

fn ppLog(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(level) > @intFromEnum(pp_log_level)) return;
    switch (scope) {
        .parser, .yaml => return,
        else => {},
    }
    var msg_buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, format, args) catch "(message too long)";
    const trimmed = std.mem.trimEnd(u8, msg, "\n");
    if (pp_json_log) {
        // Encode message as a JSON string using a fixed output buffer.
        // Uses std.debug.print for thread safety (it holds the stderr mutex).
        var out: [8192]u8 = undefined;
        var i: usize = 0;
        const prefix = std.fmt.bufPrint(out[i..], "{{\"level\":\"{s}\",\"message\":\"", .{@tagName(level)}) catch return;
        i += prefix.len;
        for (trimmed) |c| {
            if (i + 6 > out.len) break;
            switch (c) {
                '"' => {
                    out[i] = '\\';
                    out[i + 1] = '"';
                    i += 2;
                },
                '\\' => {
                    out[i] = '\\';
                    out[i + 1] = '\\';
                    i += 2;
                },
                '\n' => {
                    out[i] = '\\';
                    out[i + 1] = 'n';
                    i += 2;
                },
                '\r' => {
                    out[i] = '\\';
                    out[i + 1] = 'r';
                    i += 2;
                },
                '\t' => {
                    out[i] = '\\';
                    out[i + 1] = 't';
                    i += 2;
                },
                else => {
                    out[i] = c;
                    i += 1;
                },
            }
        }
        const suffix = "\"}\n";
        if (i + suffix.len <= out.len) {
            @memcpy(out[i..][0..suffix.len], suffix);
            i += suffix.len;
        }
        std.debug.print("{s}", .{out[0..i]});
    } else {
        std.debug.print("{s}\n", .{trimmed});
    }
}

const top_level_usage =
    \\Usage: policypress [SUBCOMMAND] [OPTIONS]
    \\
    \\Subcommands:
    \\  build            Build PDFs from policy Markdown files (default when no subcommand given)
    \\  new              Scaffold a new policy file
    \\  render-diagrams  Render site mermaid diagrams to inline SVG (run after `zola build`)
    \\  help             Show this message
    \\
    \\Run 'policypress <subcommand> --help' for subcommand-specific help.
    \\
;

pub fn main(init: std.process.Init) void {
    const io = init.io;
    const alloc = init.gpa;
    const env = init.environ_map;

    // Read argv upfront so we can route subcommands before clap sees the args.
    const argv = init.minimal.args.toSlice(init.arena.allocator()) catch {
        std.debug.print("policypress: out of memory\n", .{});
        std.process.exit(1);
    };

    // argv[0] is the binary name; user arguments start at argv[1].
    const user_args: []const [:0]const u8 = if (argv.len > 1) argv[1..] else &.{};

    // If the first user argument looks like a subcommand (no leading '-'), dispatch.
    if (user_args.len > 0 and !std.mem.startsWith(u8, user_args[0], "-")) {
        const subcmd = user_args[0];
        const rest: []const [:0]const u8 = if (user_args.len > 1) user_args[1..] else &.{};

        if (std.mem.eql(u8, subcmd, "new")) {
            runNew(io, alloc, rest) catch |err| {
                std.debug.print("policypress new: unexpected error: {s}\n", .{@errorName(err)});
                std.process.exit(1);
            };
            return;
        } else if (std.mem.eql(u8, subcmd, "build")) {
            runBuild(io, env, alloc, rest) catch |err| handleBuildError(err);
            return;
        } else if (std.mem.eql(u8, subcmd, "render-diagrams")) {
            runRenderDiagrams(io, alloc, rest) catch |err| {
                std.debug.print("policypress render-diagrams: {s}\n", .{@errorName(err)});
                std.process.exit(1);
            };
            return;
        } else if (std.mem.eql(u8, subcmd, "help")) {
            std.debug.print("{s}", .{top_level_usage});
            return;
        } else {
            std.debug.print("policypress: unknown subcommand '{s}'\n\n{s}", .{ subcmd, top_level_usage });
            std.process.exit(1);
        }
    }

    // Default: build (passing all user args as flags).
    runBuild(io, env, alloc, user_args) catch |err| handleBuildError(err);
}

fn handleBuildError(err: anyerror) void {
    switch (err) {
        // Errors that runBuild() already printed a message for — just exit.
        error.ConfigNotFound,
        error.ConfigReadFailed,
        error.ConfigInvalid,
        error.PolicyDirNotFound,
        error.PolicyDirUnreadable,
        error.OutputDirFailed,
        error.CompilationFailed,
        error.DuplicateOutputName,
        error.ValidationFailed,
        => {},
        // Anything unexpected.
        else => std.debug.print(
            "policypress: unexpected error: {s}\n",
            .{@errorName(err)},
        ),
    }
    std.process.exit(1);
}

/// `render-diagrams [DIR]` — rewrite the mermaid placeholders Zola emits into
/// inline SVG across a built site (default DIR: public). Run after `zola build`.
fn runRenderDiagrams(io: std.Io, alloc: Allocator, args: []const [:0]const u8) !void {
    var dir: []const u8 = "public";
    for (args) |a| {
        if (std.mem.eql(u8, a, "-h") or std.mem.eql(u8, a, "--help")) {
            std.debug.print(
                \\Usage: policypress render-diagrams [DIR]
                \\
                \\Rewrite <pre class="mermaid"> blocks in the built site's HTML into
                \\inline SVG (rendered in-process by pozeiden), so the site ships no
                \\client-side mermaid bundle. DIR defaults to 'public'.
                \\
            , .{});
            return;
        }
        if (!std.mem.startsWith(u8, a, "-")) dir = a;
    }
    _ = try diagrams.renderDir(io, alloc, dir);
}

/// A policy discovered in the content tree, plus whether it is out of date.
const Policy = struct {
    /// Path to the markdown source, relative to cwd.
    path: []const u8,
    /// True when the policy is out of date and must be recompiled this run.
    rebuild: bool,
};

fn runBuild(io: std.Io, env: *EnvMap, alloc: Allocator, args: []const [:0]const u8) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-c, --config <str>     Path to config file. (default: config.toml)
        \\-i, --input  <str>     Path to input content directory. (default: content)
        \\-o, --output <str>     Path to output directory. (default: <prefix>/pdfs)
        \\--draft                Add draft watermark to output (overrides config.toml).
        \\--no-draft             Do not add draft watermark to output (overrides config.toml).
        \\--redact               Redact content within redaction tags (overrides config.toml).
        \\--no-redact            Do not redact text within redaction tags (overrides config.toml).
        \\--strict               Fail the build on audit-critical policy problems (front matter, raw HTML in bodies).
        \\--audit-bundle         Write the machine-readable audit bundle (manifest, revisions, coverage) next to the PDFs (overrides config.toml).
        \\--no-audit-bundle      Do not write the audit bundle (overrides config.toml).
        \\-v, --verbose          Show debug output (typst invocations, file paths).
        \\-q, --quiet            Suppress progress output; show errors only.
        \\    --json             Emit log output as JSON lines (for CI).
    );
    var buf: [128]u8 = undefined;
    var stderr = std.Io.File.stderr().writer(io, &buf).interface;
    defer stderr.flush() catch {};
    var diag = clap.Diagnostic{};

    // Convert the sentinel-terminated slice to []const u8 for SliceIterator.
    var arg_strs = try alloc.alloc([]const u8, args.len);
    defer alloc.free(arg_strs);
    for (args, 0..) |a, i| arg_strs[i] = a;
    var iter = clap.args.SliceIterator{ .args = arg_strs };

    var res = clap.parseEx(clap.Help, &params, clap.parsers.default, &iter, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(&stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("PolicyPress\n\n", .{});
        return clap.help(&stderr, clap.Help, &params, .{});
    }

    // --- Load config ---

    const config_path = if (res.args.config) |c| c else "config.toml";
    const config_file = std.Io.Dir.cwd().openFile(io, config_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print(
                \\policypress: config file '{s}' not found.
                \\
                \\Create a config.toml with at minimum:
                \\
                \\  base_url = "https://security.example.com"
                \\  theme    = "policypress"
                \\
                \\  [extra.policypress]
                \\  organization = "Example Co"
                \\  logo         = "logo.png"
                \\  pdf_color    = "#0e90f3"
                \\  policy_dir   = "policies/"
                \\
                \\See the configuration guide for all options.
                \\
            , .{config_path});
            return error.ConfigNotFound;
        }
        std.debug.print(
            "policypress: cannot open config file '{s}': {s}\n",
            .{ config_path, @errorName(err) },
        );
        return error.ConfigReadFailed;
    };
    defer config_file.close(io);
    const contents = @import("utils").readAllAlloc(io, config_file, alloc, @import("utils").max_config_bytes) catch |err| {
        std.debug.print(
            "policypress: failed to read config file '{s}': {s}\n",
            .{ config_path, @errorName(err) },
        );
        return error.ConfigReadFailed;
    };
    defer alloc.free(contents);

    var config = Config.load(io, alloc, contents) catch |err| {
        printConfigError(config_path, err);
        return error.ConfigInvalid;
    };
    defer config.deinit(alloc);

    if (res.args.draft != 0) config.is_draft = true;
    if (res.args.@"no-draft" != 0) config.is_draft = false;
    if (res.args.redact != 0) config.redact = true;
    if (res.args.@"no-redact" != 0) config.redact = false;
    if (res.args.@"audit-bundle" != 0) config.audit_bundle = true;
    if (res.args.@"no-audit-bundle" != 0) config.audit_bundle = false;

    // `--input` re-roots the content directory (and the policy dir beneath it).
    // Config.load derives both from a hardcoded "content"; here we swap that
    // base while preserving the configured policy sub-path.
    if (res.args.input) |input| {
        const rel_policy = std.mem.trimStart(u8, config.policy_dir[config.content_dir.len..], std.fs.path.sep_str);
        const new_content = if (std.fs.path.isAbsolute(input))
            try alloc.dupe(u8, input)
        else
            try std.fs.path.join(alloc, &.{ config.root, input });
        const new_policy = try std.fs.path.join(alloc, &.{ new_content, rel_policy });
        alloc.free(config.content_dir);
        alloc.free(config.policy_dir);
        config.content_dir = new_content;
        config.policy_dir = new_policy;
    }

    if (res.args.quiet != 0) {
        pp_log_level = .err;
    } else if (res.args.verbose != 0) {
        pp_log_level = .debug;
    }
    if (res.args.json != 0) pp_json_log = true;

    std.log.debug("Running PolicyPress with configuration:\n{f}\n", .{config});

    // --- Open policy directory ---

    var policy_dir = std.Io.Dir.cwd().openDir(io, config.policy_dir, .{
        .iterate = true,
        .access_sub_paths = true,
    }) catch |err| {
        if (err == error.FileNotFound or err == error.NotDir) {
            std.debug.print(
                "policypress: policy directory '{s}' not found.\n" ++
                    "Check that 'policy_dir' in config.toml [extra] points to an existing directory under content/.\n",
                .{config.policy_dir},
            );
        } else {
            std.debug.print(
                "policypress: cannot open policy directory '{s}': {s}\n",
                .{ config.policy_dir, @errorName(err) },
            );
        }
        return error.PolicyDirNotFound;
    };
    defer policy_dir.close(io);

    var walker = policy_dir.walk(alloc) catch |err| {
        std.debug.print(
            "policypress: failed to read policy directory '{s}': {s}\n",
            .{ config.policy_dir, @errorName(err) },
        );
        return error.PolicyDirUnreadable;
    };
    defer walker.deinit();

    // --- Resolve output directory ---

    const prefix = build_options.install_prefix;
    const default_output = if (prefix.len > 0 and !std.fs.path.isAbsolute(prefix))
        try std.fmt.allocPrint(alloc, "{s}/pdfs", .{prefix})
    else
        try alloc.dupe(u8, "public/pdfs");
    defer alloc.free(default_output);

    const output_path = if (res.args.output) |o| o else default_output;
    config.build_dir = output_path;

    std.Io.Dir.cwd().createDirPath(io, output_path) catch |err| {
        std.debug.print(
            "policypress: cannot create output directory '{s}': {s}\n",
            .{ output_path, @errorName(err) },
        );
        return error.OutputDirFailed;
    };

    // Stamp directory: one file per policy, touched after successful compilation.
    // Named per build variant so regular/draft/redact caches don't collide.
    const stamps_subdir = try std.fmt.allocPrint(alloc, ".pp-stamps-d{d}-r{d}", .{
        @intFromBool(config.is_draft),
        @intFromBool(config.redact),
    });
    defer alloc.free(stamps_subdir);
    const stamps_dir_path = try std.fs.path.join(alloc, &.{ output_path, stamps_subdir });
    defer alloc.free(stamps_dir_path);
    std.Io.Dir.cwd().createDirPath(io, stamps_dir_path) catch {}; // non-fatal if it fails

    // --- Collect policy files ---
    // Retain every non-draft policy: the rebuild subset (`rebuild == true`) is
    // what gets compiled, but the full list also drives the stale-PDF sweep.
    var policies = Array(Policy).empty;
    defer {
        for (policies.items) |p| alloc.free(p.path);
        policies.deinit(alloc);
    }
    var skipped: usize = 0;
    var drafts_skipped: usize = 0;
    while (walker.next(io) catch |err| {
        std.debug.print(
            "policypress: error while scanning policy directory: {s}\n",
            .{@errorName(err)},
        );
        return error.PolicyDirUnreadable;
    }) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".md")) {
            const base_name = std.fs.path.basename(entry.path);
            if (std.mem.eql(u8, base_name, "_index.md")) continue;
            // Skip `draft: true` policies: Zola omits them from the site, so a
            // draft must not get an official-looking PDF at a guessable URL.
            // They are deliberately left out of `policies`, so the sweep below
            // also removes any PDF left over from before a policy became a draft.
            if (isDraftPolicy(io, alloc, policy_dir, entry.path)) {
                std.log.info("policypress: skipping draft policy '{s}'", .{entry.path});
                drafts_skipped += 1;
                continue;
            }
            const input_path = try std.fs.path.join(alloc, &.{ config.policy_dir, entry.path });
            const fresh = stampIsNewer(io, input_path, stamps_dir_path, alloc);
            if (fresh) skipped += 1;
            try policies.append(alloc, .{ .path = input_path, .rebuild = !fresh });
        }
    }

    var rebuild_count: usize = 0;
    for (policies.items) |p| {
        if (p.rebuild) rebuild_count += 1;
    }

    // Remove PDFs orphaned by policies that were renamed, retitled, deleted, or
    // turned into drafts. Runs even when nothing needs rebuilding, since a
    // since-deleted policy still leaves its PDF at a guessable URL otherwise.
    try sweepStalePdfs(io, alloc, config, output_path, policies.items);

    // --- Control-ID join ---
    // One read-only join (SCF catalog + optional praxis join + a library of the
    // non-draft policies) drives both control-footnote resolution during compile
    // and the control-reference preflight below. Built once here so it is shared
    // (by resolver value) across the concurrent compile task group. A missing
    // catalog degrades gracefully; a configured-but-unloadable praxis join is a
    // hard error (see ControlJoin.init).
    const scf_catalog_path = try std.fs.path.join(alloc, &.{ config.root, reports.Kind.scf.catalogFile().? });
    defer alloc.free(scf_catalog_path);
    const scf_exists = blk: {
        std.Io.Dir.cwd().access(io, scf_catalog_path, .{}) catch break :blk false;
        break :blk true;
    };
    // TSC 2017 catalog — only the control-coverage annex reads it (to title
    // tagged criteria). Absent on sites without SOC 2 data; degrades gracefully.
    const tsc_catalog_path = try std.fs.path.join(alloc, &.{ config.root, reports.Kind.soc2.catalogFile().? });
    defer alloc.free(tsc_catalog_path);
    const tsc_exists = blk: {
        std.Io.Dir.cwd().access(io, tsc_catalog_path, .{}) catch break :blk false;
        break :blk true;
    };
    const join_path: ?[]const u8 = if (config.praxis_join) |rel|
        try std.fs.path.join(alloc, &.{ config.root, rel })
    else
        null;
    defer if (join_path) |p| alloc.free(p);

    var policy_paths = try alloc.alloc([]const u8, policies.items.len);
    defer alloc.free(policy_paths);
    for (policies.items, 0..) |p, i| policy_paths[i] = p.path;

    var control_join = try controls.ControlJoin.init(
        io,
        alloc,
        if (scf_exists) scf_catalog_path else null,
        if (tsc_exists) tsc_catalog_path else null,
        join_path,
        policy_paths,
    );
    defer control_join.deinit();
    // The footnote resolver is now built PER DOCUMENT inside `compileOne` (a
    // stack-local `DocResolver` bound to that policy's path, so "See also"
    // excludes the owning policy). The annex provider stays a single read-only
    // value shared across the concurrent compile tasks.
    const control_annex_provider: ?control_annex.Provider = control_join.annexProvider();

    // --- Front-matter validation (pre-flight) ---
    // Warn on incomplete front matter; with --strict, fail on audit-critical
    // gaps. Runs over every current policy (not just the rebuild subset) so a
    // stamp-fresh policy with a blanked approval still trips --strict in CI.
    {
        const strict = res.args.strict != 0;
        var critical: usize = 0;
        var advisory: usize = 0;
        for (policies.items) |p| {
            // The more severe of the front-matter/body review and the
            // control-reference review, folded into the same counters.
            const fm_kind = config.reviewPolicyFile(io, alloc, p.path);
            const ctl_kind = control_join.reviewControlRefs(io, alloc, p.path, config.control_footnotes);
            const kind = if (@intFromEnum(fm_kind) >= @intFromEnum(ctl_kind)) fm_kind else ctl_kind;
            switch (kind) {
                .none => {},
                .advisory => advisory += 1,
                .critical => critical += 1,
            }
        }
        // #159: web-vs-PDF redaction consistency. The policy templates key the
        // linked PDF filename off the effective PDF redaction state, so links
        // resolve regardless of `redact_web`; but a build that masks the website
        // while shipping full PDFs (or vice versa) is almost always a mistake
        // and can leak the masked content through the public PDF. Advisory —
        // #115 permits web-only masking — folded into the same counter.
        switch (config.reviewRedactionConsistency()) {
            .advisory => {
                advisory += 1;
                std.log.warn(
                    "policypress: redact_web={} but PDFs are built redact={}; web masking and PDF " ++
                        "redaction diverge. Supported (#115: mask the site, keep full PDFs) but usually " ++
                        "unintended — a public site can leak the masked content through the PDF. Set " ++
                        "[extra.policypress] redact to match redact_web (or pass --redact/--no-redact) to " ++
                        "align them.",
                    .{ config.redact_web, config.redact },
                );
            },
            else => {},
        }
        if (critical + advisory > 0) {
            std.log.warn(
                "policypress: policy validation found {d} audit-critical and {d} advisory issue(s).",
                .{ critical, advisory },
            );
            // Surface the summary as a GitHub Actions annotation so it appears
            // in the workflow run UI, not only in the (often-collapsed) log.
            // Composite-action step stdout is annotation-eligible; per-file
            // annotations are a noted follow-up.
            if (env.get("GITHUB_ACTIONS") != null) {
                var abuf: [256]u8 = undefined;
                var aout = std.Io.File.stdout().writer(io, &abuf);
                aout.interface.print(
                    "::warning title=PolicyPress preflight::{d} audit-critical and {d} advisory policy issue(s); see the build log for per-file detail.\n",
                    .{ critical, advisory },
                ) catch {};
                aout.interface.flush() catch {};
            }
        }
        if (strict and critical > 0) {
            std.log.err(
                "policypress: {d} audit-critical policy problem(s); aborting (--strict).",
                .{critical},
            );
            return error.ValidationFailed;
        }
    }

    // Report PDFs regenerate on every run (before the up-to-date early return):
    // they aggregate every policy plus the control catalogs and carry the build
    // date, so they are always rebuilt — three fast typst compiles.
    try compileReports(io, env, alloc, config);

    if (rebuild_count == 0) {
        if (policies.items.len > 0) {
            std.log.info("policypress: all {d} policies are up to date.", .{policies.items.len});
        } else {
            std.log.info("policypress: no .md files found in '{s}'", .{config.policy_dir});
        }
        // The PDFs from the previous run are still current; the bundle can be
        // (re)generated from them.
        try writeAuditBundleIfEnabled(io, alloc, config, output_path);
        return;
    }
    if (skipped > 0) {
        std.log.info("policypress: {d} up to date, rebuilding {d}.", .{ skipped, rebuild_count });
    }

    // --- Detect output-filename collisions ---
    // Two policies with the same title + version resolve to the same PDF name
    // and would race to the same path during concurrent compilation, silently
    // overwriting one another (exit 0, one PDF missing). Fail loudly instead,
    // naming both offending files so the author can disambiguate.
    {
        var seen = std.StringHashMap([]const u8).init(alloc);
        defer {
            var it = seen.keyIterator();
            while (it.next()) |k| alloc.free(k.*);
            seen.deinit();
        }
        for (policies.items) |p| {
            const input_path = p.path;
            const name = Typst.outputName(io, alloc, config, input_path) catch |err| {
                // A metadata error here (e.g. missing title) will resurface as
                // a proper per-file compile error below; don't fail the whole
                // build during the collision pre-pass.
                std.log.debug("policypress: could not pre-compute output name for '{s}': {s}", .{ input_path, @errorName(err) });
                continue;
            };
            if (seen.get(name)) |other| {
                std.debug.print(
                    "policypress: two policies produce the same PDF '{s}':\n  {s}\n  {s}\n" ++
                        "Give them distinct titles or versions.\n",
                    .{ name, other, input_path },
                );
                alloc.free(name);
                return error.DuplicateOutputName;
            }
            try seen.put(name, input_path);
        }
    }

    // --- Parallel compilation ---

    const root_progress = std.Progress.start(io, .{ .root_name = "PolicyPress" });
    const compile_node = root_progress.start("compiling policies", rebuild_count);

    var error_mutex: std.Io.Mutex = .init;
    var error_count: usize = 0;
    var error_list = std.ArrayList(ErrorInfo).empty;
    defer {
        for (error_list.items) |e| alloc.free(e.path);
        error_list.deinit(alloc);
    }

    // Compile each policy concurrently via the std.Io task group (replaces the
    // removed std.Thread.Pool / WaitGroup). io.async runs tasks on the io's
    // thread pool up to its async limit; group.await joins them all.
    var group: std.Io.Group = .init;
    for (policies.items) |p| {
        if (!p.rebuild) continue;
        group.async(io, compileOne, .{
            io,
            env,
            alloc,
            config,
            p.path,
            &control_join,
            control_annex_provider,
            stamps_dir_path,
            compile_node,
            &error_mutex,
            &error_count,
            &error_list,
        });
    }
    // await blocks until every task finishes even when returning
    // error.Canceled, so no task outlives this frame; propagate the error
    // rather than reporting a cancelled build as success.
    group.await(io) catch |err| {
        compile_node.end();
        root_progress.end();
        return err;
    };

    compile_node.end();
    root_progress.end();

    if (error_count > 0) {
        std.log.err("policypress: {d} of {d} policies failed:", .{ error_count, rebuild_count });
        for (error_list.items) |e| {
            std.log.err("  ✗ {s}\n    {s}", .{ e.path, describeCompileError(e.err) });
        }
        return error.CompilationFailed;
    }

    std.log.info("policypress: {d} policies compiled successfully.", .{rebuild_count});

    // After the PDFs exist, so the manifest can hash them.
    try writeAuditBundleIfEnabled(io, alloc, config, output_path);
}

/// Write the audit bundle (#135) into the sibling `audit/` directory of the
/// PDF output (or `<output>/audit` when the output dir is not named "pdfs").
/// Official passes only: a `--draft` second pass into the same directory must
/// not overwrite the bundle with draft-flavoured entries. Redacted official
/// builds DO produce a bundle — its hashes then describe the published,
/// redacted PDFs.
fn writeAuditBundleIfEnabled(io: std.Io, alloc: Allocator, config: Config, output_path: []const u8) !void {
    if (!config.audit_bundle or config.is_draft) return;

    const audit_dir = blk: {
        if (std.mem.eql(u8, std.fs.path.basename(output_path), "pdfs")) {
            if (std.fs.path.dirname(output_path)) |parent| {
                break :blk try std.fs.path.join(alloc, &.{ parent, "audit" });
            }
            break :blk try alloc.dupe(u8, "audit");
        }
        break :blk try std.fs.path.join(alloc, &.{ output_path, "audit" });
    };
    defer alloc.free(audit_dir);

    try audit.writeBundle(io, alloc, config, audit_dir, build_options.version);
}

/// Generate the report PDFs (SCF/SOC 2 coverage, policy review) into
/// `config.build_dir` under stable, undated filenames (`reports.Kind.pdfName`;
/// the build date is inside the document). Skipped in draft passes — the
/// official pass owns these files, and a `--draft` second pass into the same
/// directory must not overwrite them with draft-flavoured copies. Redacted
/// passes DO generate them: reports carry only published-policy titles (no
/// redactable spans), and on a site whose official build is redacted (like the
/// demo) that pass is the only source. A missing control catalog skips that
/// coverage report with a note, so consumer sites without `data/` stay green.
fn compileReports(io: std.Io, env: *EnvMap, alloc: Allocator, config: Config) !void {
    if (!config.report_pdfs or config.is_draft) return;

    const generated = try std.fmt.allocPrint(alloc, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        config.date.year, config.date.month, config.date.day,
    });
    defer alloc.free(generated);

    const footer_left = try std.fmt.allocPrint(alloc, "{s} \u{00a9} {d}", .{ config.org, config.current_year });
    defer alloc.free(footer_left);

    const logo = try Typst.resolveLogoPath(io, alloc, config);
    defer if (logo) |l| alloc.free(l);

    var generated_count: usize = 0;

    inline for (comptime std.enums.values(reports.Kind)) |kind| {
        const opts: reports.render.ReportOpts = .{
            .title = kind.title(),
            .org = config.org,
            .color = Typst.validatedColor(config),
            .logo = logo,
            .footer_left = footer_left,
            .classification = config.classification,
            .generated = generated,
            .review_overdue_days = config.review_overdue_days,
        };

        const source: ?[]u8 = blk: {
            if (kind.catalogFile()) |catalog_rel| {
                const catalog_path = try std.fs.path.join(alloc, &.{ config.root, catalog_rel });
                defer alloc.free(catalog_path);
                std.Io.Dir.cwd().access(io, catalog_path, .{}) catch {
                    std.log.info(
                        "policypress: control catalog '{s}' not found; skipping the {s}",
                        .{ catalog_rel, kind.title() },
                    );
                    break :blk null;
                };
                var catalog = reports.init(io, alloc, catalog_path) catch |err| {
                    std.log.warn(
                        "policypress: could not load '{s}' ({s}); skipping the {s}",
                        .{ catalog_rel, @errorName(err), kind.title() },
                    );
                    break :blk null;
                };
                defer catalog.deinit();
                const cov = try catalog.coverage(io, kind.taxonomyKey().?, config.policy_dir);
                break :blk try reports.render.renderCoverage(alloc, cov, opts);
            } else {
                const rows = try reports.collectReviewRows(io, alloc, config.policy_dir, config.date);
                defer reports.freeReviewRows(alloc, rows);
                break :blk try reports.render.renderReview(alloc, rows, opts);
            }
        };

        if (source) |src| {
            defer alloc.free(src);
            Typst.compileSource(io, env, alloc, config, src, kind.pdfName(), kind.pdfName()) catch |err| {
                std.log.err("policypress: {s} failed: {s}", .{ kind.title(), describeCompileError(err) });
                return error.CompilationFailed;
            };
            generated_count += 1;
        }
    }

    if (generated_count > 0) {
        std.log.info("policypress: {d} report PDF(s) generated.", .{generated_count});
    }
}

/// Remove PDFs in the output directory that no longer correspond to any current
/// policy — a renamed, retitled, deleted, or newly-drafted policy would
/// otherwise leave its old PDF behind at a guessable URL. A PDF is kept if it
/// matches ANY build variant (official / draft / redacted / both) of ANY current
/// policy, so building several variants into one directory stays safe. The
/// sweep is abandoned if any policy's output name cannot be computed, so a
/// temporarily-broken front matter never causes a live PDF to be deleted.
fn sweepStalePdfs(
    io: std.Io,
    alloc: Allocator,
    config: Config,
    output_path: []const u8,
    policies: []const Policy,
) !void {
    var keep = std.StringHashMap(void).init(alloc);
    defer {
        var it = keep.keyIterator();
        while (it.next()) |k| alloc.free(k.*);
        keep.deinit();
    }

    // Every variant that changes the output filename (redact/draft are encoded
    // as a title suffix), so all coexisting variants of a live policy are kept.
    const variants = [_]struct { redact: bool, draft: bool }{
        .{ .redact = false, .draft = false },
        .{ .redact = true, .draft = false },
        .{ .redact = false, .draft = true },
        .{ .redact = true, .draft = true },
    };
    // The report PDFs live beside the policy PDFs under stable names; keep
    // them whenever report generation is enabled (they are produced by the
    // official pass, which may not be this run's variant). Mirror the
    // generation conditions: a coverage report whose control catalog was
    // removed can never be regenerated, so its stale PDF must be swept like
    // any orphaned policy PDF.
    if (config.report_pdfs) {
        inline for (comptime std.enums.values(reports.Kind)) |kind| {
            const generatable = if (kind.catalogFile()) |catalog_rel| blk: {
                const catalog_path = try std.fs.path.join(alloc, &.{ config.root, catalog_rel });
                defer alloc.free(catalog_path);
                break :blk if (std.Io.Dir.cwd().access(io, catalog_path, .{})) |_| true else |_| false;
            } else true;
            if (generatable) {
                const name = try alloc.dupe(u8, kind.pdfName());
                const gop = try keep.getOrPut(name);
                if (gop.found_existing) alloc.free(name);
            }
        }
    }

    for (policies) |p| {
        for (variants) |v| {
            var vcfg = config; // shallow copy: only reads config; never deinit'd
            vcfg.redact = v.redact;
            vcfg.is_draft = v.draft;
            const name = Typst.outputName(io, alloc, vcfg, p.path) catch |err| {
                // Can't resolve this policy's name → don't risk deleting a PDF
                // that might be its live output; skip the sweep entirely.
                std.log.debug(
                    "policypress: skipping stale-PDF sweep; cannot resolve output name for '{s}': {s}",
                    .{ p.path, @errorName(err) },
                );
                return;
            };
            const gop = try keep.getOrPut(name);
            if (gop.found_existing) alloc.free(name);
        }
    }

    var dir = std.Io.Dir.cwd().openDir(io, output_path, .{ .iterate = true }) catch |err| {
        std.log.debug(
            "policypress: skipping stale-PDF sweep; cannot open '{s}': {s}",
            .{ output_path, @errorName(err) },
        );
        return;
    };
    defer dir.close(io);

    // Collect first, then delete: mutating a directory mid-iteration is unsafe.
    var stale = Array([]const u8).empty;
    defer {
        for (stale.items) |s| alloc.free(s);
        stale.deinit(alloc);
    }
    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (!std.mem.endsWith(u8, entry.name, ".pdf")) continue;
        if (keep.contains(entry.name)) continue;
        try stale.append(alloc, try alloc.dupe(u8, entry.name));
    }

    for (stale.items) |name| {
        dir.deleteFile(io, name) catch |err| {
            std.log.warn("policypress: could not remove stale PDF '{s}': {s}", .{ name, @errorName(err) });
            continue;
        };
        std.log.info("policypress: removed stale PDF '{s}'", .{name});
    }
    if (stale.items.len > 0) {
        std.log.info("policypress: removed {d} stale PDF(s) from '{s}'.", .{ stale.items.len, output_path });
    }
}

const ErrorInfo = struct {
    path: []const u8,
    err: anyerror,
};

fn printConfigError(config_path: []const u8, err: anyerror) void {
    switch (err) {
        error.InvalidTomlConfig => std.debug.print(
            "policypress: '{s}' is not valid TOML - check for syntax errors.\n",
            .{config_path},
        ),
        error.NoExtraInZolaConfig => std.debug.print(
            "policypress: '{s}' is missing an [extra] section.\n\nAdd:\n\n" ++
                "  [extra.policypress]\n  organization = \"…\"\n  logo         = \"logo.png\"\n" ++
                "  pdf_color    = \"#0e90f3\"\n  policy_dir   = \"policies/\"\n\n",
            .{config_path},
        ),
        error.NoPolicypressBlockInConfig => std.debug.print(
            "policypress: '{s}' is missing an [extra.policypress] block.\n\nAdd:\n\n" ++
                "  [extra.policypress]\n  organization = \"…\"\n  logo         = \"logo.png\"\n" ++
                "  pdf_color    = \"#0e90f3\"\n  policy_dir   = \"policies/\"\n\n",
            .{config_path},
        ),
        error.NoBaseUrlInZolaConfig => std.debug.print(
            "policypress: '{s}' is missing 'base_url'.\n" ++
                "Add:  base_url = \"https://security.example.com\"\n\n",
            .{config_path},
        ),
        error.NoLogoInExtra => std.debug.print(
            "policypress: '{s}' [extra.policypress] is missing 'logo'.\n" ++
                "Add:  logo = \"logo.png\"  (path relative to static/)\n\n",
            .{config_path},
        ),
        error.NoOrganizationInExtra => std.debug.print(
            "policypress: '{s}' [extra.policypress] is missing 'organization'.\n" ++
                "Add:  organization = \"Your Org Name\"\n\n",
            .{config_path},
        ),
        error.NoPDFColorInExtra => std.debug.print(
            "policypress: '{s}' [extra.policypress] is missing 'pdf_color'.\n" ++
                "Add:  pdf_color = \"#0e90f3\"  (any hex color)\n\n",
            .{config_path},
        ),
        else => std.debug.print(
            "policypress: failed to load '{s}': {s}\n",
            .{ config_path, @errorName(err) },
        ),
    }
}

fn describeCompileError(err: anyerror) []const u8 {
    return switch (err) {
        error.NoTitleInFrontMatter => "front matter is missing a 'title' field",
        error.InvalidTitleType => "front matter 'title' must be a string",
        error.NoLastReviewInFrontMatter => "front matter is missing 'extra.last_reviewed' (format: YYYY-MM-DD)",
        error.InvalidLastReviewedType => "front matter 'extra.last_reviewed' must be a string in YYYY-MM-DD format",
        error.NoRevisionsInFrontMatter => "front matter is missing 'extra.major_revisions' or the list is empty",
        error.InvalidRevisionsType => "front matter 'extra.major_revisions' must be a list",
        error.NoVersionForRevision => "a revision entry in 'extra.major_revisions' is missing the 'version' field",
        error.InvalidVersionType => "a revision 'version' value must be a string (e.g. \"1.0\")",
        error.InvalidRevisionFormat => "a revision entry in 'extra.major_revisions' is not a valid mapping",
        error.NoDateForRevision => "a revision entry is missing the 'date' field",
        error.NoApprovalForRevision => "a revision entry is missing the 'approved_by' field",
        error.NoDescriptionForRevision => "a revision entry is missing the 'description' field",
        error.InvalidShortCode => "a shortcode block ({% ... %}) is malformed - check for missing {% end %}",
        error.NoResourcePathDefined => "could not determine resource path from the file's location",
        error.TypstFailed => "typst exited with an error - check the output above for details",
        error.TypstWorkFileConflict => "could not create a unique .typ work file at the site root",
        error.TypstNotFound => "typst was not found; run inside the PolicyPress devshell (nix develop) or install it from https://typst.app/open-source/",
        error.FileNotFound => "policy file was not found on disk (it may have been deleted mid-build)",
        error.OutOfMemory => "out of memory while processing this file",
        else => @errorName(err),
    };
}

// stampIsNewer and writeStamp live in utils so they can be unit-tested.
fn compileOne(
    io: std.Io,
    env: *EnvMap,
    alloc: Allocator,
    config: Config,
    input_path: []const u8,
    control_join: *const controls.ControlJoin,
    annex_provider: ?control_annex.Provider,
    stamps_dir: []const u8,
    progress_node: std.Progress.Node,
    error_mutex: *std.Io.Mutex,
    error_count: *usize,
    error_list: *std.ArrayList(ErrorInfo),
) void {
    defer progress_node.completeOne();

    // Per-document footnote resolver: a stack-local bound to this policy's path
    // so its own "See also" cross-references exclude it. Owned by this task; no
    // shared mutable resolver across the concurrent compiles.
    var doc_resolver = control_join.docResolver(input_path);
    const resolver: ?zigmark.footnotes.Resolver = doc_resolver.resolver();

    Typst.compile(io, env, alloc, config, input_path, resolver, annex_provider) catch |err| {
        error_mutex.lockUncancelable(io);
        defer error_mutex.unlock(io);
        error_count.* += 1;
        error_list.append(alloc, .{
            .path = alloc.dupe(u8, input_path) catch input_path,
            .err = err,
        }) catch {};
        return;
    };

    writeStamp(io, alloc, stamps_dir, input_path);
}

// ---------------------------------------------------------------------------
// `policypress new <name>` — scaffold a new policy file
// ---------------------------------------------------------------------------

const new_usage =
    \\Usage: policypress new [--config <path>] <policy-name>
    \\
    \\  Scaffolds a new policy Markdown file with the required front matter.
    \\  The file is created at <policy_dir>/<slug>.md relative to the config.
    \\
    \\Options:
    \\  -c, --config <path>   Path to config.toml (default: config.toml)
    \\
    \\Examples:
    \\  policypress new 'Access Control'
    \\  policypress new incident-response --config my-config.toml
    \\
;

fn runNew(io: std.Io, alloc: Allocator, args: []const [:0]const u8) !void {
    var config_path: []const u8 = "config.toml";
    var policy_name: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--config") or std.mem.eql(u8, arg, "-c")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("policypress new: --config requires a value\n\n{s}", .{new_usage});
                std.process.exit(1);
            }
            config_path = args[i];
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            std.debug.print("{s}", .{new_usage});
            return;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("policypress new: unknown flag '{s}'\n\n{s}", .{ arg, new_usage });
            std.process.exit(1);
        } else {
            if (policy_name != null) {
                std.debug.print("policypress new: unexpected argument '{s}'\n\n{s}", .{ arg, new_usage });
                std.process.exit(1);
            }
            policy_name = arg;
        }
    }

    const name = policy_name orelse {
        std.debug.print("policypress new: policy name is required\n\n{s}", .{new_usage});
        std.process.exit(1);
    };

    const config_file = std.Io.Dir.cwd().openFile(io, config_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("policypress new: config file '{s}' not found\n", .{config_path});
        } else {
            std.debug.print("policypress new: cannot open '{s}': {s}\n", .{ config_path, @errorName(err) });
        }
        std.process.exit(1);
    };
    defer config_file.close(io);

    const contents = @import("utils").readAllAlloc(io, config_file, alloc, @import("utils").max_config_bytes) catch {
        std.debug.print("policypress new: failed to read '{s}'\n", .{config_path});
        std.process.exit(1);
    };
    defer alloc.free(contents);

    var config = Config.load(io, alloc, contents) catch |err| {
        printConfigError(config_path, err);
        std.process.exit(1);
    };
    defer config.deinit(alloc);

    const slug = try newSlugify(alloc, name);
    defer alloc.free(slug);

    if (slug.len == 0) {
        std.debug.print("policypress new: policy name '{s}' produces an empty slug\n", .{name});
        std.process.exit(1);
    }

    const filename = try std.fmt.allocPrint(alloc, "{s}.md", .{slug});
    defer alloc.free(filename);

    const output_path = try std.fs.path.join(alloc, &.{ config.policy_dir, filename });
    defer alloc.free(output_path);

    // Format today's date from the wall clock via the std.Io context.
    const today = Date.today(io);
    const year = today.year;
    const month: u8 = today.month;
    const day: u8 = today.day;
    const date_str = try std.fmt.allocPrint(alloc, "{d:0>4}-{d:0>2}-{d:0>2}", .{ year, month, day });
    defer alloc.free(date_str);

    const content = try std.fmt.allocPrint(alloc,
        \\---
        \\title: "{s}"
        \\date: {s}
        \\description: ""
        \\draft: true
        \\# Map this policy to compliance-framework controls by listing control ids
        \\# (see the "Compliance Frameworks" guide). Ids must exist in your control
        \\# catalog (e.g. data/scf.json) or a --strict build fails. Uncomment to use:
        \\# taxonomies:
        \\#   SCF:
        \\#     - IAC-01
        \\#     - IAC-02
        \\extra:
        \\  last_reviewed: {s}
        \\  # Declare controls explicitly out of scope ("we do not do X"). Each entry
        \\  # needs an `id` and a non-empty `reason`; excluded controls are a distinct
        \\  # state (neither covered nor a silent gap). Uncomment to use:
        \\  # scope_exclusions:
        \\  #   - id: PES-01
        \\  #     reason: "We operate no physical facilities."
        \\  major_revisions:
        \\    - version: "0.1"
        \\      date: {s}
        \\      approved_by: ""
        \\      description: "Initial draft"
        \\---
        \\
        \\## Purpose
        \\
        \\## Scope
        \\
        \\## Policy
        \\
        \\## Exceptions
        \\
    , .{ name, date_str, date_str, date_str });
    defer alloc.free(content);

    // .exclusive = true fails atomically if the file already exists.
    const file = std.Io.Dir.cwd().createFile(io, output_path, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) {
            std.debug.print("policypress new: '{s}' already exists\n", .{output_path});
        } else {
            std.debug.print("policypress new: cannot create '{s}': {s}\n", .{ output_path, @errorName(err) });
        }
        std.process.exit(1);
    };
    defer file.close(io);

    try file.writeStreamingAll(io, content);
    std.debug.print("policypress: created {s}\n", .{output_path});
}

/// Converts a human-readable name to a URL-safe slug.
/// Runs of non-alphanumeric characters become a single hyphen.
/// Result is lowercased, with leading/trailing hyphens removed.
fn newSlugify(alloc: Allocator, name: []const u8) ![]u8 {
    var result = std.ArrayList(u8).empty;
    defer result.deinit(alloc);

    var at_separator = true;
    for (name) |c| {
        if (std.ascii.isAlphanumeric(c)) {
            try result.append(alloc, std.ascii.toLower(c));
            at_separator = false;
        } else if (!at_separator) {
            try result.append(alloc, '-');
            at_separator = true;
        }
    }
    while (result.items.len > 0 and result.getLast() == '-') _ = result.pop();
    return result.toOwnedSlice(alloc);
}

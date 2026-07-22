//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;

const BuildConfig = @import("config").Config;
const clap = @import("clap");
const zigmark = @import("zigmark");
const u = @import("utils");

/// Typst markup generation for the report PDFs (same module).
pub const render = @import("report_render.zig");

const Self = @This();
contents: []u8,
arena: std.heap.ArenaAllocator,
json: std.json.Parsed([]Control),
scf: []Control,
map: std.StringArrayHashMapUnmanaged(Control),

pub fn init(io: std.Io, alloc: Allocator, controls_file: []const u8) !Self {
    var f = std.Io.Dir.cwd().openFile(io, controls_file, .{
        .mode = .read_only,
    }) catch |e| blk: {
        if (e == error.FileNotFound) break :blk std.Io.Dir.openFileAbsolute(io, controls_file, .{ .mode = .read_only }) catch |e2| {
            std.debug.print("Controls file not found: '{s}'\n", .{controls_file});
            return e2;
        } else return e;
    };
    defer f.close(io);

    var arena = std.heap.ArenaAllocator.init(alloc);
    errdefer arena.deinit();

    const a = arena.allocator();

    var rbuf: [4096]u8 = undefined;
    var fr = f.reader(io, &rbuf);
    const c = try fr.interface.allocRemaining(a, .limited(10_000_000));
    errdefer a.free(c);
    var j = try std.json.parseFromSlice([]Control, a, c, .{});
    errdefer j.deinit();

    var m: std.StringArrayHashMapUnmanaged(Control) = .empty;
    errdefer m.deinit(a);

    for (j.value) |entry| {
        const id = entry.control_id;
        try m.put(a, id, entry);
    }

    return .{
        .contents = c,
        .arena = arena,
        .json = j,
        .scf = j.value,
        .map = m,
    };
}
pub fn deinit(self: *Self) void {
    // const a = self.arena.allocator();
    // self.json.deinit();
    // a.free(self.contents);
    // self.map.deinit();
    self.arena.deinit();
}

pub fn report(self: *Self, io: std.Io, policy_root: []const u8) ![]u8 {
    const a = self.arena.allocator();
    var ret = Array(u8).empty;
    defer ret.deinit(a);

    var pr = try std.Io.Dir.cwd().openDir(io, policy_root, .{
        .access_sub_paths = true,
        .iterate = true,
    });
    defer pr.close(io);
    var walk = try pr.walk(a);
    defer walk.deinit();

    var files = Array([]u8).empty;
    defer files.deinit(a);

    while (try walk.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.endsWith(u8, entry.basename, "_index.md")) continue;
        if (std.mem.endsWith(u8, entry.basename, ".md"))
            try files.append(a, try a.dupe(u8, entry.path));
    }

    for (files.items) |path| {
        const contents = try pr.readFileAlloc(io, path, a, .limited(10_000_000));
        defer a.free(contents);

        var fm = zigmark.Frontmatter.initFromMarkdown(a, contents) catch |e| {
            std.debug.print("Could not parse {s}\n", .{path});
            return e;
        };
        defer fm.deinit();

        const scf_controls = fm.get("taxonomies.SCF") orelse {
            std.log.warn("{s} does not have SCF controls associated with it. Skipping", .{path});
            continue;
        };
        if (scf_controls != .array) {
            std.log.warn("{s} has SCF controls in an unknown format. Skipping", .{path});
            continue;
        }
        for (scf_controls.array.items) |control| {
            if (self.map.getPtr(control.string)) |c| {
                c.found = true;
            }
        }
    }

    var iter = self.map.iterator();
    try ret.appendSlice(a, "{");
    while (iter.next()) |c| {
        const line = try std.fmt.allocPrint(
            a,
            "\"{s}\": {},",
            .{ c.key_ptr.*, c.value_ptr.found },
        );
        defer a.free(line);

        try ret.appendSlice(a, line);
    }
    if (ret.items.len > 1)
        _ = ret.pop();
    try ret.appendSlice(a, "}");
    return try ret.toOwnedSlice(a);
}

test {
    var r = try Self.init(
        tst.io,
        tst.allocator,
        "data/scf.json",
    );
    defer r.deinit();

    const out = try r.report(tst.io, "content/policies");
    const j = try std.json.parseFromSlice(std.json.Value, tst.allocator, out, .{});
    defer j.deinit();
    try tst.expect(j.value.object.count() >= 1239); // test for number of controls read as of 10/2/2025
    try tst.expect(j.value.object.get("HRS-05").?.bool);
}

const Control = struct {
    domain: []const u8,
    control_id: []const u8,
    control: []const u8,
    description: ?[]const u8 = null,
    found: bool = false,
};

pub const Report = enum {
    SOC2,
    ISO,
    SCF,
};

// ── Report PDFs: kinds, structured coverage, review rows ─────────────────────

/// The three site reports that get a generated PDF. Catalog paths are relative
/// to the site root; the PDF filenames are referenced verbatim by the report
/// templates (templates/reports/*, templates/SCF/*, templates/TSC2017/*) —
/// keep both sides in lock step.
pub const Kind = enum {
    scf,
    soc2,
    review,

    /// Control-catalog file under the site root, or null for the review
    /// report (which is driven by policy front matter alone).
    pub fn catalogFile(self: Kind) ?[]const u8 {
        return switch (self) {
            .scf => "data/scf.json",
            .soc2 => "data/tsc2017.json",
            .review => null,
        };
    }

    /// Front-matter taxonomy key whose entries map policies to this catalog.
    pub fn taxonomyKey(self: Kind) ?[]const u8 {
        return switch (self) {
            .scf => "taxonomies.SCF",
            .soc2 => "taxonomies.TSC2017",
            .review => null,
        };
    }

    pub fn title(self: Kind) []const u8 {
        return switch (self) {
            .scf => "SCF Coverage Report",
            .soc2 => "SOC 2 Coverage Report",
            .review => "Policy Review Report",
        };
    }

    pub fn pdfName(self: Kind) []const u8 {
        return switch (self) {
            .scf => "SCF_Coverage_Report.pdf",
            .soc2 => "SOC_2_Coverage_Report.pdf",
            .review => "Policy_Review_Report.pdf",
        };
    }
};

/// One catalog control with the titles of the policies that map to it.
pub const ControlCoverage = struct {
    domain: []const u8,
    control_id: []const u8,
    control: []const u8,
    /// Titles of policies whose taxonomy lists this control, sorted. Empty
    /// when the control is uncovered.
    policies: []const []const u8,
};

/// Structured coverage of one catalog: every control in catalog order plus the
/// corrected coverage numerator (distinct controls with ≥1 mapped policy).
/// Backed by the catalog's arena; freed by `deinit` on the catalog.
pub const Coverage = struct {
    controls: []ControlCoverage,
    total: usize,
    covered: usize,
};

/// Compute structured coverage: walk `policy_root` (skipping drafts, matching
/// the website, and `_index.md`), read each policy's `taxonomy_key` front
/// matter, and record which catalog controls each policy title covers.
/// Deterministic: files are walked in sorted order and each control's policy
/// list is sorted. Unknown control IDs in front matter are ignored (they can
/// not inflate coverage — the corrected numerator from #129).
pub fn coverage(self: *Self, io: std.Io, taxonomy_key: []const u8, policy_root: []const u8) !Coverage {
    const a = self.arena.allocator();

    // One policy-title list per catalog control, indexed like self.map.
    const lists = try a.alloc(Array([]const u8), self.map.count());
    for (lists) |*l| l.* = .empty;

    var pr = try std.Io.Dir.cwd().openDir(io, policy_root, .{
        .access_sub_paths = true,
        .iterate = true,
    });
    defer pr.close(io);

    var files = Array([]u8).empty;
    defer files.deinit(a);
    {
        var walk = try pr.walk(a);
        defer walk.deinit();
        while (try walk.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (std.mem.endsWith(u8, entry.basename, "_index.md")) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".md")) continue;
            try files.append(a, try a.dupe(u8, entry.path));
        }
    }
    std.mem.sort([]u8, files.items, {}, lessThanString);

    for (files.items) |path| {
        // Drafts are omitted from the site, so they must not count as coverage.
        if (u.isDraftPolicy(io, a, pr, path)) continue;

        const contents = try pr.readFileAlloc(io, path, a, .limited(10_000_000));
        defer a.free(contents);

        var fm = zigmark.Frontmatter.initFromMarkdown(a, contents) catch {
            std.log.warn("could not parse front matter of {s}; skipping in coverage", .{path});
            continue;
        };
        defer fm.deinit();

        const policy_title: []const u8 = blk: {
            if (fm.get("title")) |v| {
                if (v == .string) break :blk try a.dupe(u8, v.string);
            }
            break :blk try a.dupe(u8, path);
        };

        const controls = fm.get(taxonomy_key) orelse continue;
        if (controls != .array) continue;
        for (controls.array.items) |control| {
            if (control != .string) continue;
            const idx = self.map.getIndex(control.string) orelse continue;
            // A policy listing the same control twice still counts once.
            const list = &lists[idx];
            if (list.items.len > 0 and std.mem.eql(u8, list.items[list.items.len - 1], policy_title)) continue;
            try list.append(a, policy_title);
        }
    }

    var out = try a.alloc(ControlCoverage, self.map.count());
    var covered: usize = 0;
    var it = self.map.iterator();
    var i: usize = 0;
    while (it.next()) |entry| : (i += 1) {
        std.mem.sort([]const u8, lists[i].items, {}, lessThanConstString);
        if (lists[i].items.len > 0) covered += 1;
        out[i] = .{
            .domain = entry.value_ptr.domain,
            .control_id = entry.value_ptr.control_id,
            .control = entry.value_ptr.control,
            .policies = lists[i].items,
        };
    }

    return .{ .controls = out, .total = out.len, .covered = covered };
}

fn lessThanString(_: void, lhs: []u8, rhs: []u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

fn lessThanConstString(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

/// One row of the policy-review report.
pub const ReviewRow = struct {
    title: []const u8,
    version: []const u8,
    owner: ?[]const u8,
    last_reviewed: []const u8,
    /// Whole days between `last_reviewed` and the build date; null when the
    /// date does not parse.
    days_since: ?i64,
};

/// Collect one review row per non-draft policy under `policy_root`, sorted by
/// last-reviewed date then title (matching the website's review report).
/// `date` is the build date review ages are measured against. All strings are
/// allocated from `alloc`; free via `freeReviewRows`.
pub fn collectReviewRows(io: std.Io, alloc: Allocator, policy_root: []const u8, date: u.Date) ![]ReviewRow {
    var rows = Array(ReviewRow).empty;
    errdefer freeReviewRowsList(alloc, &rows);

    var pr = try std.Io.Dir.cwd().openDir(io, policy_root, .{
        .access_sub_paths = true,
        .iterate = true,
    });
    defer pr.close(io);

    var files = Array([]u8).empty;
    defer {
        for (files.items) |f| alloc.free(f);
        files.deinit(alloc);
    }
    {
        var walk = try pr.walk(alloc);
        defer walk.deinit();
        while (try walk.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (std.mem.endsWith(u8, entry.basename, "_index.md")) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".md")) continue;
            try files.append(alloc, try alloc.dupe(u8, entry.path));
        }
    }
    std.mem.sort([]u8, files.items, {}, lessThanString);

    const today_day = date.epochDay();

    for (files.items) |path| {
        if (u.isDraftPolicy(io, alloc, pr, path)) continue;

        const contents = try pr.readFileAlloc(io, path, alloc, .limited(10_000_000));
        defer alloc.free(contents);

        var fm = zigmark.Frontmatter.initFromMarkdown(alloc, contents) catch {
            std.log.warn("could not parse front matter of {s}; skipping in review report", .{path});
            continue;
        };
        defer fm.deinit();

        const title_str: []const u8 = blk: {
            if (fm.get("title")) |v| {
                if (v == .string) break :blk v.string;
            }
            break :blk path;
        };

        const last_reviewed: []const u8 = blk: {
            if (fm.get("extra.last_reviewed")) |v| {
                if (v == .string) break :blk v.string;
            }
            break :blk "";
        };

        // Newest revision's version, matching the site/PDF selection.
        var ver_buf: [32]u8 = undefined;
        const version: []const u8 = blk: {
            const revisions = fm.get("extra.major_revisions") orelse break :blk "";
            if (revisions != .array) break :blk "";
            const newest = u.newestRevision(revisions.array.items) orelse break :blk "";
            const v = newest.get("version") orelse break :blk "";
            break :blk switch (v) {
                .string => |s| s,
                .float => |f| std.fmt.bufPrint(&ver_buf, "{d}", .{f}) catch "",
                .integer => |n| std.fmt.bufPrint(&ver_buf, "{d}", .{n}) catch "",
                else => "",
            };
        };

        const owner: ?[]const u8 = blk: {
            if (fm.get("extra.owner")) |v| {
                if (v == .string and v.string.len > 0) break :blk v.string;
            }
            break :blk null;
        };

        const days_since: ?i64 = blk: {
            const d = u.Date.parse(last_reviewed) orelse break :blk null;
            break :blk today_day - d.epochDay();
        };

        try rows.append(alloc, .{
            .title = try alloc.dupe(u8, title_str),
            .version = try alloc.dupe(u8, version),
            .owner = if (owner) |o| try alloc.dupe(u8, o) else null,
            .last_reviewed = try alloc.dupe(u8, last_reviewed),
            .days_since = days_since,
        });
    }

    std.mem.sort(ReviewRow, rows.items, {}, reviewRowLessThan);
    return rows.toOwnedSlice(alloc);
}

fn reviewRowLessThan(_: void, lhs: ReviewRow, rhs: ReviewRow) bool {
    return switch (std.mem.order(u8, lhs.last_reviewed, rhs.last_reviewed)) {
        .lt => true,
        .gt => false,
        .eq => std.mem.order(u8, lhs.title, rhs.title) == .lt,
    };
}

pub fn freeReviewRows(alloc: Allocator, rows: []ReviewRow) void {
    for (rows) |r| {
        alloc.free(r.title);
        alloc.free(r.version);
        if (r.owner) |o| alloc.free(o);
        alloc.free(r.last_reviewed);
    }
    alloc.free(rows);
}

fn freeReviewRowsList(alloc: Allocator, rows: *Array(ReviewRow)) void {
    for (rows.items) |r| {
        alloc.free(r.title);
        alloc.free(r.version);
        if (r.owner) |o| alloc.free(o);
        alloc.free(r.last_reviewed);
    }
    rows.deinit(alloc);
}

pub fn main(pctx: std.process.Init) !void {
    const io = pctx.io;
    var arena = std.heap.ArenaAllocator.init(pctx.gpa);
    defer arena.deinit();

    const alloc = arena.allocator();

    var config = try BuildConfig.load_config_toml(io, alloc);
    defer config.deinit(alloc);

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\--report <REPORT>      Report type to run
    );

    var buffer: [128]u8 = undefined;
    var output_writer = std.Io.File.stdout().writer(io, &buffer);
    const stdout: *std.Io.Writer = &output_writer.interface;

    var buffer2: [128]u8 = undefined;
    var err_writer = std.Io.File.stderr().writer(io, &buffer2);
    const stderr: *std.Io.Writer = &err_writer.interface;

    var diag = clap.Diagnostic{};
    var res = clap.parse(
        clap.Help,
        &params,
        .{
            .REPORT = clap.parsers.enumeration(Report),
        },
        pctx.minimal.args,
        .{
            .diagnostic = &diag,
            .allocator = alloc,
        },
    ) catch |err| {
        // Report useful error and exit.
        diag.report(stderr, err) catch {};
        return err;
    };
    defer res.deinit();
    if (res.args.help != 0) {
        std.debug.print(
            \\Policy Report
            \\Returns JSON to stdout describing controls' presence in the policies
        , .{});
        return clap.help(stderr, clap.Help, &params, .{});
    }
    const path = if (res.args.report) |r| blk: {
        // Control data lives in data/<standard>.json (e.g. data/scf.json); the
        // enum tag is upper-case (SCF), so lower-case it to match the filename.
        const lower = try std.ascii.allocLowerString(alloc, @tagName(r));
        defer alloc.free(lower);
        break :blk try std.fmt.allocPrint(alloc, "data/{s}.json", .{lower});
    } else {
        std.debug.print("No Report specified\n", .{});
        return error.NoReportSpecified;
    };
    defer alloc.free(path);
    var rep = try init(
        io,
        alloc,
        path,
    );
    defer rep.deinit();
    const r = try rep.report(io, config.policy_dir);

    try stdout.print("{s}", .{r});

    try stdout.flush(); // Don't forget to flush!
    try stderr.flush(); // Don't forget to flush!

}

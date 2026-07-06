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
    // std.debug.print("Getting reports from {s}\n", .{config.policy_dir});
    const r = try rep.report(io, config.policy_dir);

    try stdout.print("{s}", .{r});

    try stdout.flush(); // Don't forget to flush!
    try stderr.flush(); // Don't forget to flush!

}

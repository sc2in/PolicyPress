const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const Yaml = @import("yaml").Yaml;
const FM = @import("frontmatter.zig");
const clap = @import("clap");
const Self = @This();
const BuildConfig = @import("config.zig").Config;

contents: []u8,
arena: std.heap.ArenaAllocator,
json: std.json.Parsed([]Control),
scf: []Control,
map: std.StringArrayHashMap(Control),

pub fn init(alloc: Allocator, controls_file: []const u8) !Self {
    var f = std.fs.cwd().openFile(controls_file, .{
        .mode = .read_only,
    }) catch |e| blk: {
        if (e == error.FileNotFound) break :blk std.fs.openFileAbsolute(controls_file, .{ .mode = .read_only }) catch |e2| {
            std.debug.print("Controls file not found: '{s}'\n", .{controls_file});
            return e2;
        } else return e;
    };
    defer f.close();

    var arena = std.heap.ArenaAllocator.init(alloc);
    errdefer arena.deinit();

    const a = arena.allocator();

    const c = try f.readToEndAlloc(a, 10_000_000);
    errdefer a.free(c);
    var j = try std.json.parseFromSlice([]Control, a, c, .{});
    errdefer j.deinit();

    var m = std.StringArrayHashMap(Control).init(a);
    errdefer m.deinit();

    for (j.value) |entry| {
        const id = entry.control_id;
        try m.put(id, entry);
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

pub fn report(self: *Self, policy_root: []const u8) ![]u8 {
    const a = self.arena.allocator();
    var ret = Array(u8){};
    defer ret.deinit(a);

    var pr = try std.fs.cwd().openDir(policy_root, .{
        .access_sub_paths = true,
        .iterate = true,
    });
    defer pr.close();
    var walk = try pr.walk(a);
    defer walk.deinit();

    var files = Array([]u8){};
    defer files.deinit(a);

    while (try walk.next()) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.endsWith(u8, entry.basename, "_index.md")) continue;
        if (std.mem.endsWith(u8, entry.basename, ".md"))
            try files.append(a, try a.dupe(u8, entry.path));
    }

    for (files.items) |path| {
        var f = try pr.openFile(path, .{ .mode = .read_only });
        defer f.close();

        const contents = try f.readToEndAlloc(a, 10_000_000);
        defer a.free(contents);

        var fm = FM.initFromMarkdown(a, contents) catch |e| {
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
        tst.allocator,
        "templates/opencontrols/standards/SCF.json",
    );
    defer r.deinit();

    const out = try r.report("content/policies");
    const j = try std.json.parseFromSlice(std.json.Value, tst.allocator, out, .{});
    defer j.deinit();
    try tst.expect(j.value.object.count() >= 1239); // test for number of controls read as of 10/2/2025
    try tst.expect(j.value.object.get("HRS-05").?.bool);
}

const Control = struct {
    domain: []const u8,
    control_id: []const u8,
    control: []const u8,
    description: []const u8,
    found: bool = false,
};

pub const Report = enum {
    SOC2,
    ISO,
    SCF,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();

    var config = try BuildConfig.load_config_toml(alloc);
    defer config.deinit(alloc);

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\--report <REPORT>      Report type to run
    );

    var buffer: [128]u8 = undefined;
    var output_writer: std.fs.File.Writer = std.fs.File.stdout().writer(&buffer);
    const stdout: *std.Io.Writer = &output_writer.interface;

    var buffer2: [128]u8 = undefined;
    var err_writer: std.fs.File.Writer = std.fs.File.stderr().writer(&buffer2);
    const stderr: *std.Io.Writer = &err_writer.interface;

    var diag = clap.Diagnostic{};
    var res = clap.parse(
        clap.Help,
        &params,
        .{
            .REPORT = clap.parsers.enumeration(Report),
        },
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
            \\SC2 Policy Report
            \\Returns a json of controls' presence in the policies
        , .{});
        return clap.help(stderr, clap.Help, &params, .{});
    }
    const path = if (res.args.report) |r| blk: {
        break :blk try std.fmt.allocPrint(
            alloc,
            "templates/opencontrols/standards/{s}.json",
            .{@tagName(r)},
        );
    } else {
        std.debug.print("No Report specified\n", .{});
        return error.NoReportSpecified;
    };
    defer alloc.free(path);
    var rep = try init(
        alloc,
        path,
    );
    defer rep.deinit();
    // std.debug.print("Getting reports from {s}\n", .{config.policy_dir});
    const r = try rep.report(config.policy_dir);

    try stdout.print("{s}", .{r});

    try stdout.flush(); // Don't forget to flush!
    try stderr.flush(); // Don't forget to flush!

}

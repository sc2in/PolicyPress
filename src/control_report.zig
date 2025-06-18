const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const Yaml = @import("yaml").Yaml;
const FM = @import("frontmatter.zig");

const Self = @This();

contents: []u8,
arena: std.heap.ArenaAllocator,
json: std.json.Parsed([]Control),
scf: []Control,
map: std.StringArrayHashMap(Control),

pub fn init(alloc: Allocator, controls_file: []const u8) !Self {
    var f = try std.fs.cwd().openFile(controls_file, .{
        .mode = .read_only,
    });
    defer f.close();
    errdefer f.close();

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
    var prog = std.Progress.start(.{
        .root_name = "Control Satisfaction Report",
    });
    defer prog.end();
    const a = self.arena.allocator();
    var ret = Array(u8).init(a);
    defer ret.deinit();

    var pr = try std.fs.cwd().openDir(policy_root, .{
        .access_sub_paths = true,
        .iterate = true,
    });
    defer pr.close();
    var walk = try pr.walk(a);
    defer walk.deinit();

    var files = Array([]u8).init(a);
    defer files.deinit();

    while (try walk.next()) |entry| {
        var p = prog.start("Checking files", 0);
        defer p.end();
        if (entry.kind != .file) continue;
        if (std.mem.endsWith(u8, entry.basename, "_index.md")) continue;
        if (std.mem.endsWith(u8, entry.basename, ".md"))
            try files.append(try a.dupe(u8, entry.path));
    }
    var p1 = prog.start("Processing policies", files.items.len);
    defer p1.end();
    for (files.items) |path| {
        var p2 = p1.start(path, 1);
        defer p2.end();
        var f = try pr.openFile(path, .{ .mode = .read_only });
        defer f.close();

        const contents = try f.readToEndAlloc(a, 10_000_000);
        defer a.free(contents);

        const end_fm = std.mem.indexOfPos(u8, contents, 3, "---") orelse return error.InvalidFrontMatter;

        var fm = FM.init(a, contents[3..end_fm], .yaml) catch |e| {
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
    var p2 = prog.start("Generating Report", self.map.values().len);
    defer p2.end();
    var iter = self.map.iterator();
    while (iter.next()) |c| {
        const line = try std.fmt.allocPrint(a, "{s}: {}\n", .{ c.key_ptr.*, c.value_ptr.found });
        defer a.free(line);

        try ret.appendSlice(line);
    }
    return try ret.toOwnedSlice();
}

test {
    var r = try Self.init(tst.allocator, "templates/opencontrols/standards/SCF.json");
    defer r.deinit();

    const out = try r.report("content/policies");
    std.debug.print("{s}", .{out});
}

const Control = struct {
    domain: []const u8,
    control_id: []const u8,
    control: []const u8,
    description: []const u8,
    found: bool = false,
};

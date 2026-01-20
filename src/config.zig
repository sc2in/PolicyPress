const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const fm = @import("frontmatter.zig");
const toml = fm.tomlz;
const dt = @import("datetime");
const u = @import("utils.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .config, .level = std.log.default_level },
        .{ .scope = .yaml, .level = .err },
    },
    .logFn = u.logFn,
};

const conflog = std.log.scoped(.config);
pub const Config = struct {
    base_url: []const u8,
    org: []const u8,
    logo_path: []const u8,
    color: []const u8,
    policy_dir: []const u8,
    content_dir: []const u8,
    current_year: u16,
    root: []const u8,
    is_draft: bool = false,
    redact: bool = false,
    build_dir: []const u8,
    date: dt.datetime.Date,

    zola_config: ?toml.Table,

    pub fn format(self: Config, writer: *std.Io.Writer) !void {
        var buf: [4096]u8 = undefined;
        var gpa = std.heap.FixedBufferAllocator.init(&buf);
        const alloc = gpa.allocator();
        var stringy = self.toValue(alloc) catch |e| {
            conflog.err("Formatting Error: {}\n", .{e});
            return error.WriteFailed;
        };
        defer stringy.object.deinit();

        // std.debug.print("{}\n", .{config});
        const output = std.json.Stringify.valueAlloc(
            alloc,
            stringy,
            .{ .whitespace = .indent_1 },
        ) catch |e| {
            conflog.err("Stringify Error: {}\n", .{e});
            return error.WriteFailed;
        };
        defer alloc.free(output);
        try writer.print("{s}", .{output});
    }
    pub fn load_config_toml(alloc: Allocator) !Config {
        conflog.info("Loading config.toml", .{});
        const file = try std.fs.cwd().openFile("config.toml", .{});
        defer file.close();

        const content = try file.readToEndAlloc(alloc, 1024 * 1024 * 1024);
        defer alloc.free(content);

        return try Config.load(alloc, content);
    }
    pub fn toValue(self: Config, alloc: Allocator) !std.json.Value {
        var obj = std.json.ObjectMap.init(alloc);
        try obj.put("base_url", .{ .string = self.base_url });
        try obj.put("organization", .{ .string = self.org });
        try obj.put("logo_path", .{ .string = self.logo_path });
        try obj.put("pdf_color", .{ .string = self.color });
        try obj.put("policy_dir", .{ .string = self.policy_dir });
        try obj.put("content_dir", .{ .string = self.content_dir });
        try obj.put("current_year", .{ .integer = @intCast(self.current_year) });
        try obj.put("root", .{ .string = self.root });
        try obj.put("is_draft", .{ .bool = self.is_draft });
        try obj.put("redact", .{ .bool = self.redact });
        try obj.put("build_dir", .{ .string = self.build_dir });

        errdefer obj.deinit();

        return .{ .object = obj };
    }

    pub fn load(alloc: Allocator, content: []const u8) !Config {
        var t = try toml.parse(alloc, content);
        errdefer t.deinit(alloc);
        const e = t.getTable("extra") orelse return error.NoExtraInZolaConfig;
        //BUG: This doesnt work in zig 0.14.1, but should in 0.14.0.
        // const b = try tomlz.decode(BuildConfig, allocator, content);
        // if (b.root.len == 0) return error.NoRootInConfig;
        // if (b.base_url.len == 0) return error.NoBaseUrlInConfig;
        // if (b.logo_path.len == 0) return error.NoLogoInExtra;
        // if (b.color.len == 0) return error.NoPDFColorInExtra;
        // if (b.org.len == 0) return error.NoOrganizationInExtra;
        var config: Config = undefined;
        config.date = dt.datetime.Datetime.now().date;

        try config.validate(t);
        config.root = try std.fs.cwd().realpathAlloc(alloc, ".");
        config.current_year = config.date.year;

        config.base_url = t.getString("base_url").?;
        config.content_dir = try std.fs.path.join(alloc, &.{
            config.root,
            "content",
        });
        config.policy_dir = try std.fs.path.join(alloc, &.{
            config.content_dir,
            e.getString("policy_dir").?,
        });
        config.logo_path = try std.fs.path.join(alloc, &.{
            config.root,
            "static",
            e.getString("logo").?,
        });
        config.color = e.getString("pdf_color").?;
        config.org = e.getString("organization").?;
        config.build_dir = "zig-out/pdfs";
        config.zola_config = t;
        config.redact = e.getBool("redact") orelse return error.NoRedactInZolaExtra;
        return config;
    }
    pub fn deinit(self: *Config, alloc: Allocator) void {
        if (self.zola_config) |*c| c.deinit(alloc);
        alloc.free(self.root);
        alloc.free(self.logo_path);
        alloc.free(self.policy_dir);
        alloc.free(self.content_dir);
    }

    pub fn validate(_: Config, zolaConfig: toml.Table) !void {
        if (zolaConfig.getTable("extra")) |ex| {
            if (ex.getString("logo") == null) return error.NoLogoInExtra;
            if (ex.getString("organization") == null) return error.NoOrganizationInExtra;
            if (ex.getString("pdf_color") == null) return error.NoPDFColorInExtra;
        } else return error.NoExtraInZolaConfig;
        if (zolaConfig.getString("base_url") == null) return error.NoBaseUrlInZolaConfig;
    }

    pub fn validatePolicyFiles(self: Config, alloc: Allocator) !void {
        conflog.debug("\n\nValidating policies from {s}\n", .{self.policy_dir});
        var policy_dir = try std.fs.cwd().openDir(
            self.policy_dir,
            .{
                .access_sub_paths = true,
                .iterate = true,
            },
        );
        defer policy_dir.close();

        var it = try policy_dir.walk(alloc);
        defer it.deinit();

        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".md")) continue;
            if (std.mem.eql(u8, entry.basename, "_index.md")) continue;
            conflog.debug("Validating Policy File: {s}\n", .{entry.path});
            const file_path = try std.fs.path.join(alloc, &.{ self.policy_dir, entry.path });
            defer alloc.free(file_path);

            const file = try std.fs.openFileAbsolute(file_path, .{ .mode = .read_only });
            defer file.close();

            const content = try file.readToEndAlloc(alloc, 10 * 1024 * 1024);
            defer alloc.free(content);

            var frontMatter = try fm.initFromMarkdown(alloc, content);
            defer frontMatter.deinit();

            self.validateFrontMatter(frontMatter) catch |e| {
                conflog.err("Error processing {s}\n{}\n", .{ file_path, e });
                return e;
            };
        }
    }

    pub fn validateFrontMatter(_: Config, frontMatter: fm) !void {
        if (frontMatter.get("title") == null) return error.NoTitleInFrontMatter;
        conflog.debug("Validating: {s}\n", .{frontMatter.get("title").?.string});
        if (frontMatter.get("description") == null) return error.NoDescriptionInFrontMatter;
        if (frontMatter.get("extra.last_reviewed") == null) return error.NoLastReviewInFrontMatter;
        const revs = frontMatter.get("extra.major_revisions") orelse return error.NoRevisionsInFrontMatter;
        if (revs.array.items.len == 0) return error.NoRevisionsInFrontMatter;
        for (revs.array.items) |rev| {
            _ = rev.object.getKey("date") orelse return error.NoDateForRevision;
            _ = rev.object.getKey("approved_by") orelse return error.NoApprovalForRevision;
            _ = rev.object.getKey("version") orelse return error.NoVersionForRevision;
            _ = rev.object.getKey("description") orelse return error.NoDescriptionForRevision;
        }
        // _ = frontMatter.get("date") orelse return error.NoDateInFrontMatter;
    }
};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var buffer: [128]u8 = undefined;
    var output_writer: std.fs.File.Writer = std.fs.File.stdout().writer(&buffer);
    const stdout: *std.Io.Writer = &output_writer.interface;

    var config = try Config.load_config_toml(allocator);
    defer config.deinit(allocator);
    try config.validatePolicyFiles(allocator);

    try stdout.print("{f}\n", .{config});
    try stdout.flush();
}

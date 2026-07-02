//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;
const zigmark = @import("zigmark");
const toml = @import("tomlz");
const u = @import("utils");

pub const std_options: std.Options = .{
    .log_level = .warn,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .config, .level = .warn },
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
    /// Temporary directory containing the embedded eisvogel.latex template,
    /// passed to pandoc as --data-dir.  Owned and freed by the caller.
    data_dir: []const u8 = "",
    date: u.Date,

    zola_config: ?toml.Table,

    pub fn format(self: Config, writer: *std.Io.Writer) !void {
        var buf: [4096]u8 = undefined;
        var gpa = std.heap.FixedBufferAllocator.init(&buf);
        const alloc = gpa.allocator();
        var stringy = self.toValue(alloc) catch |e| {
            conflog.err("Formatting Error: {}\n", .{e});
            return error.WriteFailed;
        };
        defer stringy.object.deinit(alloc);

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
    pub fn load_config_toml(io: std.Io, alloc: Allocator) !Config {
        conflog.debug("Loading config.toml", .{});
        const content = try std.Io.Dir.cwd().readFileAlloc(io, "config.toml", alloc, .limited(1024 * 1024));
        defer alloc.free(content);

        return try Config.load(io, alloc, content);
    }
    pub fn toValue(self: Config, alloc: Allocator) !std.json.Value {
        var obj: std.json.ObjectMap = .empty;
        errdefer obj.deinit(alloc);
        try obj.put(alloc, "base_url", .{ .string = self.base_url });
        try obj.put(alloc, "organization", .{ .string = self.org });
        try obj.put(alloc, "logo_path", .{ .string = self.logo_path });
        try obj.put(alloc, "pdf_color", .{ .string = self.color });
        try obj.put(alloc, "policy_dir", .{ .string = self.policy_dir });
        try obj.put(alloc, "content_dir", .{ .string = self.content_dir });
        try obj.put(alloc, "current_year", .{ .integer = @intCast(self.current_year) });
        try obj.put(alloc, "root", .{ .string = self.root });
        try obj.put(alloc, "is_draft", .{ .bool = self.is_draft });
        try obj.put(alloc, "redact", .{ .bool = self.redact });
        try obj.put(alloc, "build_dir", .{ .string = self.build_dir });

        return .{ .object = obj };
    }

    pub fn load(io: std.Io, alloc: Allocator, content: []const u8) !Config {
        var t = toml.parse(alloc, content) catch |e| {
            conflog.err("TOML Parse Error: {}\n", .{e});
            return error.InvalidTomlConfig;
        };
        errdefer t.deinit(alloc);
        const extra = t.getTable("extra") orelse return error.NoExtraInZolaConfig;
        const e = extra.getTable("policypress") orelse return error.NoPolicypressBlockInConfig;
        //BUG: This doesnt work in zig 0.14.1, but should in 0.14.0.
        // const b = try tomlz.decode(BuildConfig, allocator, content);
        // if (b.root.len == 0) return error.NoRootInConfig;
        // if (b.base_url.len == 0) return error.NoBaseUrlInConfig;
        // if (b.logo_path.len == 0) return error.NoLogoInExtra;
        // if (b.color.len == 0) return error.NoPDFColorInExtra;
        // if (b.org.len == 0) return error.NoOrganizationInExtra;
        var config: Config = undefined;
        config.data_dir = "";
        config.is_draft = false;
        config.date = u.Date.today(io);

        try config.validate(t);
        var root_buf: [std.fs.max_path_bytes]u8 = undefined;
        const root_len = try std.process.currentPath(io, &root_buf);
        config.root = try alloc.dupe(u8, root_buf[0..root_len]);
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
        config.build_dir = "public";
        config.zola_config = t;
        config.redact = e.getBool("redact_web") orelse false;
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
        const extra = zolaConfig.getTable("extra") orelse return error.NoExtraInZolaConfig;
        const pp = extra.getTable("policypress") orelse return error.NoPolicypressBlockInConfig;
        if (pp.getString("logo") == null) return error.NoLogoInExtra;
        if (pp.getString("organization") == null) return error.NoOrganizationInExtra;
        if (pp.getString("pdf_color") == null) return error.NoPDFColorInExtra;
        if (zolaConfig.getString("base_url") == null) return error.NoBaseUrlInZolaConfig;
    }

    pub fn validatePolicyFiles(self: Config, io: std.Io, alloc: Allocator) !void {
        conflog.debug("\n\nValidating policies from {s}\n", .{self.policy_dir});
        var policy_dir = try std.Io.Dir.cwd().openDir(
            io,
            self.policy_dir,
            .{
                .access_sub_paths = true,
                .iterate = true,
            },
        );
        defer policy_dir.close(io);

        var it = try policy_dir.walk(alloc);
        defer it.deinit();

        while (try it.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".md")) continue;
            if (std.mem.eql(u8, entry.basename, "_index.md")) continue;
            conflog.debug("Validating Policy File: {s}\n", .{entry.path});

            const content = try policy_dir.readFileAlloc(io, entry.path, alloc, .limited(10 * 1024 * 1024));
            defer alloc.free(content);

            var frontMatter = try zigmark.Frontmatter.initFromMarkdown(alloc, content);
            defer frontMatter.deinit();

            self.validateFrontMatter(frontMatter) catch |e| {
                conflog.err("Error processing {s}\n{}\n", .{ entry.path, e });
                return e;
            };
        }
    }

    pub fn validateFrontMatter(_: Config, frontMatter: zigmark.Frontmatter) !void {
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

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    var buffer: [128]u8 = undefined;
    var output_writer = std.Io.File.stdout().writer(io, &buffer);
    const stdout: *std.Io.Writer = &output_writer.interface;

    var config = try Config.load_config_toml(io, allocator);
    defer config.deinit(allocator);
    try config.validatePolicyFiles(io, allocator);

    try stdout.print("{f}\n", .{config});
    try stdout.flush();
}

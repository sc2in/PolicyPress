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
        // PDF redaction is controlled only by --redact/--no-redact (and the
        // action's redact_mode input). `redact_web` is read by the Zola
        // templates for the website's redaction bars and deliberately does
        // not affect PDFs: an org may hide content (e.g. phone numbers) on
        // the public site while keeping it in the PDFs. (#115)
        config.redact = false;
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
            // Presence *and* non-emptiness: an audit PDF must never ship with a
            // blank `approved_by` (the revision would claim approval by nobody).
            // `.getKey` only interns the key name, so read the value with `.get`.
            const approved_by = rev.object.get("approved_by") orelse return error.NoApprovalForRevision;
            switch (approved_by) {
                .string => |s| if (std.mem.trim(u8, s, " \t\r\n").len == 0) return error.EmptyApprovalForRevision,
                else => {},
            }
            _ = rev.object.getKey("version") orelse return error.NoVersionForRevision;
            _ = rev.object.getKey("description") orelse return error.NoDescriptionForRevision;
        }
        // _ = frontMatter.get("date") orelse return error.NoDateInFrontMatter;
    }

    /// Severity of a policy's validation problems.
    pub const IssueKind = enum { none, advisory, critical };

    /// Validate one policy file without stopping the build. Checks front matter
    /// and the Markdown body, logging each specific problem and classifying it.
    /// A missing `description` is advisory (it feeds teasers/SEO, not the audit
    /// trail); anything that undermines the audit record is critical: bad front
    /// matter (title, approvals, revision dates/versions, an unparseable file)
    /// or raw HTML in the body (the website renders it but the Typst/PDF path
    /// silently drops it, so the two artifacts would diverge — see
    /// `reviewPolicyBody`). The caller decides whether critical issues abort the
    /// build (see `--strict`). `path` is resolved from cwd.
    pub fn reviewPolicyFile(self: Config, io: std.Io, alloc: Allocator, path: []const u8) IssueKind {
        const content = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .limited(10 * 1024 * 1024)) catch |err| {
            conflog.warn("{s}: cannot read for validation: {s}", .{ path, @errorName(err) });
            return .critical;
        };
        defer alloc.free(content);

        var frontMatter = zigmark.Frontmatter.initFromMarkdown(alloc, content) catch |err| {
            conflog.warn("{s}: cannot parse front matter: {s}", .{ path, @errorName(err) });
            return .critical;
        };
        defer frontMatter.deinit();

        self.validateFrontMatter(frontMatter) catch |err| switch (err) {
            error.NoDescriptionInFrontMatter, error.NoDescriptionForRevision => {
                conflog.warn("{s}: missing description (advisory)", .{path});
                // A body problem outranks the advisory. IssueKind is ordered
                // none < advisory < critical, so take the more severe of the two.
                const body = reviewPolicyBody(alloc, path, content);
                return if (@intFromEnum(body) > @intFromEnum(IssueKind.advisory)) body else .advisory;
            },
            else => {
                conflog.warn("{s}: {s}", .{ path, @errorName(err) });
                return .critical;
            },
        };
        return reviewPolicyBody(alloc, path, content);
    }

    /// Check the Markdown body for constructs that silently diverge between the
    /// website and the PDF. Currently one rule: raw or inline HTML, which Zola
    /// renders on the site (`page.content | safe`) but zigmark's Typst renderer
    /// omits (`renderers/typst.zig` drops `html_block`/`html_in_line`), so a PDF
    /// would be missing content the website shows. Critical, because a divergent
    /// audit record is an integrity failure. Detection is AST-based, so `<div>`
    /// inside a code fence/span and `<user@host>` autolinks never false-positive.
    fn reviewPolicyBody(alloc: Allocator, path: []const u8, content: []const u8) IssueKind {
        const finding = findRawHtml(alloc, content) catch |err| {
            conflog.warn("{s}: cannot parse body for validation: {s}", .{ path, @errorName(err) });
            return .critical;
        };
        if (finding) |f| {
            defer f.deinit(alloc);
            conflog.warn(
                "{s}: raw HTML in policy body ('{s}'): the website renders it but it is silently dropped from the PDF; remove it or fence it as a code example",
                .{ path, f.snippet },
            );
            return .critical;
        }
        return .none;
    }

    /// Whether the dropped HTML was a block (`<div>…</div>`) or inline (`<br>`).
    pub const RawHtmlKind = enum { block, in_line };

    /// A raw-HTML occurrence in a Markdown body that the Typst renderer would
    /// silently drop.
    pub const RawHtmlFinding = struct {
        kind: RawHtmlKind,
        /// Owned, truncated copy of the offending markup; caller frees.
        snippet: []u8,

        pub fn deinit(self: RawHtmlFinding, alloc: Allocator) void {
            alloc.free(self.snippet);
        }
    };

    /// Parse `content` (frontmatter included — the parser skips it exactly like
    /// the PDF render path in `typst.zig`) and return the first raw/inline HTML
    /// node, or null when the body has none. AST-based via zigmark's own parser,
    /// so it matches precisely what the renderer would drop.
    pub fn findRawHtml(alloc: Allocator, content: []const u8) !?RawHtmlFinding {
        var parser = zigmark.Parser.init();
        defer parser.deinit(alloc);
        var doc = try parser.parseMarkdown(alloc, content);
        defer doc.deinit(alloc);

        const hit = firstRawHtmlInBlocks(doc.children.items) orelse return null;

        // Report the first line only, capped at 80 bytes, without splitting a
        // UTF-8 sequence: enough for the author to locate the tag.
        var snip = std.mem.trim(u8, hit.content, " \t\r\n");
        if (std.mem.indexOfScalar(u8, snip, '\n')) |nl| snip = snip[0..nl];
        var end = @min(snip.len, 80);
        while (end < snip.len and (snip[end] & 0xC0) == 0x80) end -= 1;
        return .{ .kind = hit.kind, .snippet = try alloc.dupe(u8, snip[0..end]) };
    }
};

/// Borrowed reference to a raw-HTML node in a parsed document. `content` points
/// into the `Document`, so callers must copy it out before the document is freed.
const RawHtmlRef = struct {
    kind: Config.RawHtmlKind,
    content: []const u8,
};

/// Depth-first search for the first raw HTML node reachable from `blocks`.
/// Switches are exhaustive on purpose: if a future zigmark bump adds a block
/// kind, this fails to compile so the rule gets revisited.
fn firstRawHtmlInBlocks(blocks: []const zigmark.AST.Block) ?RawHtmlRef {
    for (blocks) |*block| switch (block.*) {
        .html_block => |hb| return .{ .kind = .block, .content = hb.content },
        .paragraph => |p| if (firstRawHtmlInInlines(p.children.items)) |f| return f,
        .heading => |h| if (firstRawHtmlInInlines(h.children.items)) |f| return f,
        .blockquote => |bq| if (firstRawHtmlInBlocks(bq.children.items)) |f| return f,
        .footnote_definition => |fd| if (firstRawHtmlInBlocks(fd.children.items)) |f| return f,
        .list => |l| for (l.items.items) |*item| {
            if (firstRawHtmlInBlocks(item.children.items)) |f| return f;
        },
        .table => |t| {
            for (t.header.cells.items) |*cell| {
                if (firstRawHtmlInInlines(cell.children.items)) |f| return f;
            }
            for (t.body.items) |*row| for (row.cells.items) |*cell| {
                if (firstRawHtmlInInlines(cell.children.items)) |f| return f;
            };
        },
        // Leaf blocks with no raw-HTML nodes. Code blocks are excluded on
        // purpose: `<div>` inside a fence is content, not markup.
        .code_block, .fenced_code_block, .thematic_break => {},
    };
    return null;
}

/// Depth-first search for the first raw inline HTML reachable from `inlines`.
fn firstRawHtmlInInlines(inlines: []const zigmark.AST.Inline) ?RawHtmlRef {
    for (inlines) |*il| switch (il.*) {
        .html_in_line => |h| return .{ .kind = .in_line, .content = h.content },
        .emphasis => |e| if (firstRawHtmlInInlines(e.children.items)) |f| return f,
        .strong => |s| if (firstRawHtmlInInlines(s.children.items)) |f| return f,
        .strikethrough => |s| if (firstRawHtmlInInlines(s.children.items)) |f| return f,
        .link => |l| if (firstRawHtmlInInlines(l.children.items)) |f| return f,
        // Leaf inlines. `autolink` is deliberately treated as non-HTML:
        // `<user@host>` / `<https://…>` are autolinks, which the PDF renders.
        .text, .code_span, .image, .autolink, .footnote_reference, .hard_break, .soft_break => {},
    };
    return null;
}

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

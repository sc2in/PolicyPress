//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//!
//! Control-ID join for policy PDFs (#127 / #164).
//!
//! Binds three read-only data sources so that inline control references become
//! footnotes carrying auditable context:
//!
//!   * the SCF control catalog (`data/scf.json`, via `control_report.zig`) — the
//!     control title;
//!   * the optional praxis join (`data/praxis-join.json`) — whether the control
//!     is in praxis's actively-governed spine; and
//!   * a `zigmark.Library` of the non-draft policies — the render-time reverse
//!     lookup (control id → covering policy titles) that exists nowhere else.
//!
//! `ControlJoin` produces a `zigmark.footnotes.Resolver`: given a control label
//! like `IAC-01`, it returns the Markdown definition body that
//! `zigmark.footnotes.resolve` synthesises into the AST, which the Typst
//! renderer then expands to a native `#footnote[…]`. Every clause degrades: a
//! missing catalog drops the title, a missing join drops the praxis clause, no
//! covering policy drops that clause — the id alone is always a valid footnote.
//!
//! `ControlJoin` is additive: it never touches `control_report.zig`'s
//! `coverage()`, whose draft-exclusion / dedup / corrected-numerator logic stays
//! canonical. After construction it is read-only, so a single instance is shared
//! (by resolver value) across the concurrent per-policy compile tasks.

const std = @import("std");
const Allocator = std.mem.Allocator;
const tst = std.testing;

const zigmark = @import("zigmark");
const reports = @import("reports");
const praxis_join = @import("praxis_join");
const Config = @import("config").Config;
const u = @import("utils");
const mvzr = @import("mvzr");

const ctrllog = std.log.scoped(.controls);

/// The one control-id shape the whole toolchain agrees on:
/// `^[A-Z]{2,5}-[0-9]{2}(\.[0-9]+)*$` (e.g. `IAC-01`, `HRS-05.1`, `IAC-21.5`).
/// Implemented by hand rather than via a regex so it can anchor exactly and be
/// reused for both validation and dangling-reference filtering without pulling
/// mvzr anchoring semantics into the hot path.
pub fn isControlId(s: []const u8) bool {
    var i: usize = 0;
    var letters: usize = 0;
    while (i < s.len and s[i] >= 'A' and s[i] <= 'Z') : (i += 1) letters += 1;
    if (letters < 2 or letters > 5) return false;
    if (i >= s.len or s[i] != '-') return false;
    i += 1;
    // Exactly two digits.
    if (i + 2 > s.len or !isDigit(s[i]) or !isDigit(s[i + 1])) return false;
    i += 2;
    // Zero or more `.<digits>` sub-control segments.
    while (i < s.len) {
        if (s[i] != '.') return false;
        i += 1;
        var digits: usize = 0;
        while (i < s.len and isDigit(s[i])) : (i += 1) digits += 1;
        if (digits == 0) return false;
    }
    return i == s.len;
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

/// The more severe of two issue kinds (Config.IssueKind is ordered
/// none < advisory < critical). Mirrors config.zig's private `maxKind`.
fn maxKind(a: Config.IssueKind, b: Config.IssueKind) Config.IssueKind {
    return if (@intFromEnum(a) >= @intFromEnum(b)) a else b;
}

pub const ControlJoin = struct {
    /// SCF catalog instance (`control_report.zig`), or null when `data/scf.json`
    /// is absent — the resolver then omits the title clause and validation skips
    /// the unknown-id check.
    catalog: ?reports,
    /// praxis spine membership, or null when no join file is configured.
    join: ?praxis_join.PraxisJoin,
    /// The non-draft policies, queried for covering-policy titles.
    library: zigmark.Library,

    /// Build a `ControlJoin`.
    ///
    /// `catalog_path` / `join_path` are optional; `policy_paths` are the
    /// non-draft policy files (resolved from the process working directory) fed
    /// into the library one at a time (never `addFromDir`, which would pull in
    /// drafts and `_index.md`).
    ///
    /// A missing/unreadable catalog degrades to `null` (footnotes lose the title
    /// clause but stay valid). A configured-but-unloadable praxis join is a hard
    /// error — silently dropping coverage data would be worse than failing.
    pub fn init(
        io: std.Io,
        alloc: Allocator,
        catalog_path: ?[]const u8,
        join_path: ?[]const u8,
        policy_paths: []const []const u8,
    ) !ControlJoin {
        var catalog: ?reports = null;
        errdefer if (catalog) |*c| c.deinit();
        if (catalog_path) |cp| {
            catalog = reports.init(io, alloc, cp) catch |err| blk: {
                ctrllog.info(
                    "control catalog '{s}' unavailable ({s}); footnotes will omit control titles",
                    .{ cp, @errorName(err) },
                );
                break :blk null;
            };
        }

        var join: ?praxis_join.PraxisJoin = null;
        errdefer if (join) |*j| j.deinit();
        if (join_path) |jp| {
            join = try praxis_join.PraxisJoin.load(io, alloc, jp);
            // A configured catalog and join built from different SCF versions is a
            // maintenance smell: spine ids the local catalog does not know cannot
            // be titled. Advisory, so builds still pass (SCF-version skew is the
            // author's to reconcile, not a hard failure).
            if (catalog) |*c| {
                for (join.?.ids) |id| {
                    if (!c.map.contains(id)) {
                        ctrllog.warn(
                            "praxis spine id '{s}' is not in the local control catalog (SCF version skew)",
                            .{id},
                        );
                    }
                }
            }
        }

        var library = zigmark.Library.init(alloc);
        errdefer library.deinit();
        for (policy_paths) |path| {
            const src = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .limited(u.max_policy_bytes)) catch |err| {
                ctrllog.warn("could not read policy '{s}' for the control library: {s}", .{ path, @errorName(err) });
                continue;
            };
            defer alloc.free(src);
            library.add(src, path) catch |err| {
                ctrllog.warn("could not index policy '{s}' for the control library: {s}", .{ path, @errorName(err) });
                continue;
            };
        }

        return .{ .catalog = catalog, .join = join, .library = library };
    }

    pub fn deinit(self: *ControlJoin) void {
        if (self.catalog) |*c| c.deinit();
        if (self.join) |*j| j.deinit();
        self.library.deinit();
    }

    /// A `zigmark.footnotes.Resolver` bound to this join. The returned resolver
    /// borrows `self`; it must not outlive the `ControlJoin`.
    pub fn resolver(self: *const ControlJoin) zigmark.footnotes.Resolver {
        return .{ .ctx = @constCast(self), .resolveFn = resolveThunk };
    }

    fn resolveThunk(ctx: ?*anyopaque, alloc: Allocator, label: []const u8) anyerror!?[]const u8 {
        const self: *const ControlJoin = @ptrCast(@alignCast(ctx.?));
        return self.resolveFootnote(alloc, label);
    }

    /// Markdown definition body for a control footnote, or null when `label` is
    /// not a control id (so a genuinely unknown footnote reference stays
    /// dangling for validation to catch). Shape:
    ///
    ///   `IAC-01 — <title>. praxis: in control spine. Covered by: A, B.`
    ///
    /// with any clause omitted when its data source is absent. Caller owns the
    /// returned slice (zigmark frees it, per the resolver contract).
    pub fn resolveFootnote(self: *const ControlJoin, alloc: Allocator, label: []const u8) !?[]const u8 {
        if (!isControlId(label)) return null;

        var aw: std.Io.Writer.Allocating = .init(alloc);
        defer aw.deinit();

        // First sentence: the id and, when the catalog knows it, its title.
        try aw.writer.writeAll(label);
        if (self.catalog) |*cat| {
            if (cat.map.get(label)) |ctrl| {
                try aw.writer.print(" \u{2014} {s}", .{std.mem.trim(u8, ctrl.control, " ")});
            }
        }
        try aw.writer.writeByte('.');

        // praxis spine clause (only when a join is configured).
        if (self.join) |*j| {
            try aw.writer.print(" praxis: {s}.", .{
                if (j.contains(label)) "in control spine" else "not in control spine",
            });
        }

        // Covering-policy clause (only when ≥1 non-draft policy tags the control).
        const covering = try self.coveringPolicies(alloc, label);
        defer alloc.free(covering);
        if (covering.len > 0) {
            try aw.writer.writeAll(" Covered by: ");
            for (covering, 0..) |title, i| {
                if (i > 0) try aw.writer.writeAll(", ");
                try aw.writer.writeAll(title);
            }
            try aw.writer.writeByte('.');
        }

        return try aw.toOwnedSlice();
    }

    /// Sorted, deduplicated titles of the non-draft policies whose
    /// `taxonomies.SCF` lists `label`. The returned slice is owned by the caller
    /// (`alloc.free`); its elements borrow from the library's frontmatter, which
    /// lives for the whole build.
    fn coveringPolicies(self: *const ControlJoin, alloc: Allocator, label: []const u8) ![]const []const u8 {
        const q = try std.fmt.allocPrint(alloc, "taxonomies.SCF={s}", .{label});
        defer alloc.free(q);

        const results = (try self.library.query(alloc, q)) orelse return &.{};
        defer alloc.free(results);

        var titles = std.ArrayList([]const u8).empty;
        errdefer titles.deinit(alloc);
        for (results) |r| {
            const fm = r.entry.frontmatter orelse continue;
            const title_v = fm.get("title") orelse continue;
            if (title_v != .string) continue;
            const title = title_v.string;
            var seen = false;
            for (titles.items) |existing| {
                if (std.mem.eql(u8, existing, title)) {
                    seen = true;
                    break;
                }
            }
            if (!seen) try titles.append(alloc, title);
        }
        std.mem.sort([]const u8, titles.items, {}, lessThanStr);
        return titles.toOwnedSlice(alloc);
    }

    /// Preflight validation of a single policy's control references, feeding the
    /// same critical/advisory severity model as `config.reviewPolicyFile` (so
    /// `--strict` aborts on a critical result). Reads and parses `path` itself,
    /// mirroring `reviewPolicyFile`. Rules (all critical):
    ///
    ///   * a malformed or unknown id in `taxonomies.SCF`;
    ///   * a malformed or unknown id in a `control(...)` shortcode; and
    ///   * a control-shaped raw `[^ID]` footnote reference in the body (the
    ///     author must use the `control(id="…")` shortcode so the reference
    ///     resolves on both the website and the PDF — same web/PDF-divergence
    ///     rationale as the raw-HTML rule).
    ///
    /// Unknown-id checks are skipped when no catalog is loaded (nothing to check
    /// against). Non-control footnote references are ignored here.
    pub fn reviewControlRefs(self: *const ControlJoin, io: std.Io, alloc: Allocator, path: []const u8) Config.IssueKind {
        const content = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .limited(u.max_policy_bytes)) catch |err| {
            ctrllog.warn("{s}: cannot read for control validation: {s}", .{ path, @errorName(err) });
            return .critical;
        };
        defer alloc.free(content);

        var worst: Config.IssueKind = .none;
        worst = maxKind(worst, self.reviewTaxonomy(alloc, path, content));
        worst = maxKind(worst, self.reviewShortcodes(path, content));
        worst = maxKind(worst, self.reviewDanglingRefs(alloc, path, content));
        return worst;
    }

    /// `taxonomies.SCF` ids: malformed shape or (when a catalog is present)
    /// unknown id → critical.
    fn reviewTaxonomy(self: *const ControlJoin, alloc: Allocator, path: []const u8, content: []const u8) Config.IssueKind {
        var fm = zigmark.Frontmatter.initFromMarkdown(alloc, content) catch |err| {
            // Front-matter parse failures are reported by config.reviewPolicyFile;
            // don't double-count them as a control problem here.
            ctrllog.debug("{s}: front matter unparseable for control validation: {s}", .{ path, @errorName(err) });
            return .none;
        };
        defer fm.deinit();

        const scf = fm.get("taxonomies.SCF") orelse return .none;
        if (scf != .array) return .none;

        var worst: Config.IssueKind = .none;
        for (scf.array.items) |item| {
            if (item != .string) continue;
            const id = item.string;
            if (!isControlId(id)) {
                ctrllog.warn("{s}: malformed SCF control id '{s}' in taxonomies.SCF (expected e.g. IAC-01)", .{ path, id });
                worst = .critical;
            } else if (self.catalog) |*cat| {
                if (!cat.map.contains(id)) {
                    ctrllog.warn("{s}: unknown SCF control id '{s}' in taxonomies.SCF (not in data/scf.json)", .{ path, id });
                    worst = .critical;
                }
            }
        }
        return worst;
    }

    /// `control(...)` shortcodes in the body: an unknown (but well-formed) id →
    /// critical; any `control(` opener the strict pattern did not consume is a
    /// malformed shortcode → critical (mirrors `utils.replace_control_refs`).
    fn reviewShortcodes(self: *const ControlJoin, path: []const u8, content: []const u8) Config.IssueKind {
        const opener: mvzr.Regex = mvzr.compile("\\{\\{\\s*control\\(").?;
        if (!opener.isMatch(content)) return .none;
        const strict: mvzr.Regex = mvzr.compile("\\{\\{\\s*control\\(id=\"[A-Z]{2,5}-[0-9]{2}(\\.[0-9]+)*\"\\)\\s*\\}\\}").?;

        var worst: Config.IssueKind = .none;

        var strict_count: usize = 0;
        var it = strict.iterator(content);
        while (it.next()) |m| {
            strict_count += 1;
            const key = "id=\"";
            const s = std.mem.indexOf(u8, m.slice, key) orelse continue;
            const id_start = s + key.len;
            const id_end = std.mem.indexOfScalarPos(u8, m.slice, id_start, '"') orelse continue;
            const id = m.slice[id_start..id_end];
            if (self.catalog) |*cat| {
                if (!cat.map.contains(id)) {
                    ctrllog.warn("{s}: unknown SCF control id '{s}' in a control() shortcode (not in data/scf.json)", .{ path, id });
                    worst = .critical;
                }
            }
        }

        var opener_count: usize = 0;
        var oit = opener.iterator(content);
        while (oit.next()) |_| opener_count += 1;
        if (opener_count > strict_count) {
            ctrllog.warn("{s}: malformed control() shortcode (bad or missing id; use the control(id=\"IAC-01\") form)", .{path});
            worst = .critical;
        }
        return worst;
    }

    /// Control-shaped raw `[^ID]` footnote references with no definition in the
    /// body → critical. Parses the raw body (shortcodes are still `{{ … }}`
    /// text at this stage, so only author-typed `[^…]` refs are found).
    fn reviewDanglingRefs(_: *const ControlJoin, alloc: Allocator, path: []const u8, content: []const u8) Config.IssueKind {
        var parser = zigmark.Parser.init();
        defer parser.deinit(alloc);
        var doc = parser.parseMarkdown(alloc, content) catch |err| {
            ctrllog.debug("{s}: body unparseable for footnote validation: {s}", .{ path, @errorName(err) });
            return .none;
        };
        defer doc.deinit(alloc);

        const dangs = zigmark.footnotes.dangling(alloc, &doc) catch return .none;
        defer {
            for (dangs) |d| alloc.free(d);
            alloc.free(dangs);
        }

        var worst: Config.IssueKind = .none;
        for (dangs) |label| {
            if (!isControlId(label)) continue;
            ctrllog.warn(
                "{s}: raw footnote reference '[^{s}]' in the body; use the control(id=\"{s}\") shortcode so it resolves on both the website and the PDF",
                .{ path, label, label },
            );
            worst = .critical;
        }
        return worst;
    }
};

fn lessThanStr(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "isControlId: shapes accepted and rejected" {
    try tst.expect(isControlId("IAC-01"));
    try tst.expect(isControlId("HRS-05.1"));
    try tst.expect(isControlId("IAC-21.5"));
    try tst.expect(isControlId("ABCDE-01")); // 5 letters
    try tst.expect(isControlId("GOV-01.2.3"));
    try tst.expect(!isControlId("iac-01")); // lowercase
    try tst.expect(!isControlId("A-01")); // 1 letter
    try tst.expect(!isControlId("ABCDEF-01")); // 6 letters
    try tst.expect(!isControlId("IAC-1")); // 1 digit
    try tst.expect(!isControlId("IAC01")); // no hyphen
    try tst.expect(!isControlId("IAC-01.")); // trailing dot
    try tst.expect(!isControlId("IAC-01.x")); // non-digit sub
    try tst.expect(!isControlId(""));
}

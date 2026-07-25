//! Copyright © 2026 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 OR PolyForm-Internal-Use-1.0.0
//!
//! Control-ID join for policy PDFs (#127 / #164).
//!
//! Binds two read-only data sources so that inline control references become
//! footnotes carrying auditable context:
//!
//!   * the SCF control catalog (`data/scf.json`, via `control_report.zig`) — the
//!     control title; and
//!   * a `zigmark.Library` of the non-draft policies — the render-time reverse
//!     lookup (control id → covering policy titles) that exists nowhere else.
//!
//! The footnote body is **praxis-agnostic** (#172/#174): praxis spine
//! membership is an optional overlay surfaced on the web badges, the PDF
//! coverage annex, and `audit/join.json` — never repeated inline in every
//! footnote. The one residual praxis touch in this file is a load-time catalog
//! skew diagnostic, quarantined behind `checkPraxisCatalogSkew` (see below); it
//! reads the join purely to warn, and does not shape any rendered output.
//!
//! `ControlJoin` produces a per-document `zigmark.footnotes.Resolver` (via
//! `DocResolver`): given a control label like `IAC-01`, it returns the Markdown
//! definition body that `zigmark.footnotes.resolve` synthesises into the AST,
//! which the Typst renderer then expands to a native `#footnote[…]`. Shape:
//! `IAC-01 — <title>. See also: <other covering policies>.` — every clause
//! degrades: a missing catalog drops the title, and no *other* covering policy
//! drops the "See also" clause (the id alone is always a valid footnote). The
//! resolver is per-document so "See also" can exclude the policy that owns the
//! footnote (it never lists itself).
//!
//! `ControlJoin` is additive: it never touches `control_report.zig`'s
//! `coverage()`, whose draft-exclusion / dedup / corrected-numerator logic stays
//! canonical. After construction it is read-only, so a single instance is shared
//! across the concurrent per-policy compile tasks; each task wraps it in its own
//! stack-local `DocResolver` bound to that policy's path.

const std = @import("std");
const Allocator = std.mem.Allocator;
const tst = std.testing;

const annex = @import("control_annex");
const Config = @import("config").Config;
const mvzr = @import("mvzr");
const praxis_join = @import("praxis_join");
const reports = @import("reports");
const u = @import("utils");
const zigmark = @import("zigmark");

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
    /// TSC 2017 (SOC 2) catalog instance, or null when `data/tsc2017.json` is
    /// absent. Only the control-coverage annex reads it (to title tagged
    /// `taxonomies.TSC2017` criteria); footnote resolution and validation are
    /// SCF-only.
    tsc_catalog: ?reports,
    /// The optional praxis join — the SINGLE praxis seam in this core type.
    /// Held only to drive the load-time catalog-skew diagnostic
    /// (`checkPraxisCatalogSkew`); it is deliberately *not* read by
    /// `resolveFootnote` (footnotes are praxis-agnostic, #172/#174). Null when
    /// no join file is configured, so a praxis-free build touches none of it.
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
        tsc_catalog_path: ?[]const u8,
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

        // TSC 2017 catalog for the annex; degrades to null exactly like the SCF
        // catalog (the annex then shows tagged criteria by id alone).
        var tsc_catalog: ?reports = null;
        errdefer if (tsc_catalog) |*c| c.deinit();
        if (tsc_catalog_path) |tp| {
            tsc_catalog = reports.init(io, alloc, tp) catch |err| blk: {
                ctrllog.info(
                    "TSC 2017 catalog '{s}' unavailable ({s}); the coverage annex will omit criterion titles",
                    .{ tp, @errorName(err) },
                );
                break :blk null;
            };
        }

        var join: ?praxis_join.PraxisJoin = null;
        errdefer if (join) |*j| j.deinit();
        if (join_path) |jp| {
            join = try praxis_join.PraxisJoin.load(io, alloc, jp);
            checkPraxisCatalogSkew(join.?, if (catalog) |*c| c else null);
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

        return .{ .catalog = catalog, .tsc_catalog = tsc_catalog, .join = join, .library = library };
    }

    pub fn deinit(self: *ControlJoin) void {
        if (self.catalog) |*c| c.deinit();
        if (self.tsc_catalog) |*c| c.deinit();
        if (self.join) |*j| j.deinit();
        self.library.deinit();
    }

    /// Build a per-document footnote resolver bound to this join and to
    /// `self_path` — the path (relative to `config.root`) of the policy being
    /// compiled. "See also" cross-references exclude that policy so a footnote
    /// never lists the document it lives in. Pass null for a document-agnostic
    /// resolver (every covering policy is listed).
    ///
    /// The returned `DocResolver` borrows both `self` and `self_path`; keep it
    /// alive for the whole compile. Because compilation is concurrent across
    /// policies, each task must build (and own) its own `DocResolver` — never
    /// share one mutable instance.
    pub fn docResolver(self: *const ControlJoin, self_path: ?[]const u8) DocResolver {
        return .{ .join = self, .self_path = self_path };
    }

    /// A `control_annex.Provider` bound to this join, for the PDF control-coverage
    /// annex. Answers the one global lookup (control/criterion title) that
    /// `typst.zig` cannot do itself; the per-policy tags come from the frontmatter
    /// typst already parses. The annex is praxis-agnostic — spine membership is an
    /// optional overlay (web badges + join.json), not part of the core table. The
    /// returned provider borrows `self`; it must not outlive the `ControlJoin`.
    /// Read-only, so safe to share (by value) across the concurrent compile tasks.
    pub fn annexProvider(self: *const ControlJoin) annex.Provider {
        return .{
            .ctx = @constCast(self),
            .lookupFn = annexLookupThunk,
        };
    }

    fn annexLookupThunk(ctx: ?*anyopaque, framework: annex.Framework, id: []const u8) annex.Info {
        const self: *const ControlJoin = @ptrCast(@alignCast(ctx.?));
        const cat: ?*const reports = switch (framework) {
            .scf => if (self.catalog) |*c| c else null,
            .tsc2017 => if (self.tsc_catalog) |*c| c else null,
        };
        const title: ?[]const u8 = if (cat) |c| blk: {
            const ctrl = c.map.get(id) orelse break :blk null;
            break :blk std.mem.trim(u8, ctrl.control, " ");
        } else null;
        return .{ .title = title };
    }

    /// Markdown definition body for a control footnote, or null when `label` is
    /// not a control id (so a genuinely unknown footnote reference stays
    /// dangling for validation to catch). Shape:
    ///
    ///   `IAC-01 — <title>. See also: A, B.`
    ///
    /// The body is praxis-agnostic (#172/#174): no spine clause. "See also"
    /// lists the *other* non-draft policies that address the control (excluding
    /// `self_path`, the policy that owns the footnote); it is omitted entirely
    /// when no other policy covers the control, and the title clause is omitted
    /// when the catalog is absent (the id alone is always a valid footnote).
    /// Caller owns the returned slice (zigmark frees it, per the resolver
    /// contract).
    pub fn resolveFootnote(
        self: *const ControlJoin,
        alloc: Allocator,
        label: []const u8,
        self_path: ?[]const u8,
    ) !?[]const u8 {
        return self.resolveFootnoteImpl(alloc, label, self_path, null);
    }

    /// Like `resolveFootnote`, but renders the leading control id as a Markdown
    /// link to `link_url` with a `#<id>` fragment — the web path used by the
    /// `stage-site` pass (#173), so a synthesised definition's id links to the
    /// control's row on the SCF report page (paralleling the `control()`
    /// shortcode's inline link). `link_url` is an already-resolved site path
    /// (e.g. `/reports/scf/`); pass null to emit a plain id.
    ///
    /// The PDF path always goes through `resolveFootnote` (link_url = null), so
    /// the Typst output — and every golden — stays byte-identical. Only the web
    /// definitions carry the link.
    pub fn resolveFootnoteLinked(
        self: *const ControlJoin,
        alloc: Allocator,
        label: []const u8,
        self_path: ?[]const u8,
        link_url: ?[]const u8,
    ) !?[]const u8 {
        return self.resolveFootnoteImpl(alloc, label, self_path, link_url);
    }

    fn resolveFootnoteImpl(
        self: *const ControlJoin,
        alloc: Allocator,
        label: []const u8,
        self_path: ?[]const u8,
        link_url: ?[]const u8,
    ) !?[]const u8 {
        if (!isControlId(label)) return null;

        var aw: std.Io.Writer.Allocating = .init(alloc);
        defer aw.deinit();

        // First sentence: the id — linked to the report-page anchor on the web,
        // plain in the PDF — and, when the catalog knows it, its title.
        if (link_url) |url| {
            try aw.writer.print("[{s}]({s}#{s})", .{ label, url, label });
        } else {
            try aw.writer.writeAll(label);
        }
        if (self.catalog) |*cat| {
            if (cat.map.get(label)) |ctrl| {
                try aw.writer.print(" \u{2014} {s}", .{std.mem.trim(u8, ctrl.control, " ")});
            }
        }
        try aw.writer.writeByte('.');

        // "See also" clause: the OTHER non-draft policies tagging this control,
        // excluding the current one. Omitted when no other policy covers it.
        const also = try self.coveringPolicies(alloc, label, self_path);
        defer alloc.free(also);
        if (also.len > 0) {
            try aw.writer.writeAll(" See also: ");
            for (also, 0..) |title, i| {
                if (i > 0) try aw.writer.writeAll(", ");
                try aw.writer.writeAll(title);
            }
            try aw.writer.writeByte('.');
        }

        return try aw.toOwnedSlice();
    }

    /// Sorted, deduplicated titles of the non-draft policies whose
    /// `taxonomies.SCF` lists `label`, excluding the policy at `exclude_path`
    /// (pass null to exclude none). The returned slice is owned by the caller
    /// (`alloc.free`); its elements borrow from the library's frontmatter, which
    /// lives for the whole build.
    fn coveringPolicies(
        self: *const ControlJoin,
        alloc: Allocator,
        label: []const u8,
        exclude_path: ?[]const u8,
    ) ![]const []const u8 {
        const q = try std.fmt.allocPrint(alloc, "taxonomies.SCF={s}", .{label});
        defer alloc.free(q);

        const results = (try self.library.query(alloc, q)) orelse return &.{};
        defer alloc.free(results);

        var titles = std.ArrayList([]const u8).empty;
        errdefer titles.deinit(alloc);
        for (results) |r| {
            // Skip the current policy so its own footnotes never list it.
            if (exclude_path) |ep| {
                if (r.entry.path) |rp| {
                    if (std.mem.eql(u8, rp, ep)) continue;
                }
            }
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
    ///   * a control-shaped raw `[^ID]` footnote reference in the body — see
    ///     `reviewDanglingRefs`. Whether such a ref is critical depends on
    ///     `native_refs_ok` (`[extra.policypress] control_footnotes`, #173): with
    ///     native footnotes off it is always critical (the author must use the
    ///     shortcode so the ref resolves on both web and PDF); with them on only
    ///     an UNKNOWN id is (the `stage-site` pass synthesises the web definition
    ///     for known ids).
    ///
    /// Unknown-id checks are skipped when no catalog is loaded (nothing to check
    /// against). Non-control footnote references are ignored here.
    ///
    /// One **advisory** (non-critical) rule: a known control referenced *inline*
    /// in the body (a `control(...)` shortcode, or — with native footnotes on — a
    /// `[^ID]` reference) but absent from `taxonomies.SCF`. It renders, but
    /// coverage (the SCF report, the coverage annex, the audit bundle) is
    /// front-matter-driven, so the mention does not count toward coverage — see
    /// `reviewInlineCoverage`.
    ///
    /// Scope exclusions (`extra.scope_exclusions`) are also validated: a
    /// malformed/unknown id or a missing reason is critical, an id both covered
    /// and excluded by the same policy is critical, and a control excluded here
    /// but covered by *another* policy is an advisory (a legitimate governance
    /// tension for praxis to adjudicate — the repo-wide view comes from the
    /// shared library).
    pub fn reviewControlRefs(self: *const ControlJoin, io: std.Io, alloc: Allocator, path: []const u8, native_refs_ok: bool) Config.IssueKind {
        const content = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .limited(u.max_policy_bytes)) catch |err| {
            ctrllog.warn("{s}: cannot read for control validation: {s}", .{ path, @errorName(err) });
            return .critical;
        };
        defer alloc.free(content);

        var worst: Config.IssueKind = .none;
        worst = maxKind(worst, self.reviewTaxonomy(alloc, path, content));
        worst = maxKind(worst, self.reviewShortcodes(path, content));
        worst = maxKind(worst, self.reviewDanglingRefs(alloc, path, content, native_refs_ok));
        worst = maxKind(worst, self.reviewInlineCoverage(alloc, path, content, native_refs_ok));
        worst = maxKind(worst, self.reviewExclusions(alloc, path, content));
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
    /// body. Parses the raw body (shortcodes are still `{{ … }}` text at this
    /// stage, so only author-typed `[^…]` refs are found).
    ///
    /// Behaviour depends on whether native control footnotes are enabled for this
    /// build (`native_refs_ok`, from `[extra.policypress] control_footnotes`, #173):
    ///
    ///   * disabled (default): ANY control-shaped dangling ref → critical. A bare
    ///     `[^ID]` resolves in the PDF (the synthesiser) but is dead text on the
    ///     website with no synthesis pass, so the author must use the
    ///     `control(id="…")` shortcode (or enable `control_footnotes`).
    ///   * enabled: a KNOWN id — or any id when no catalog is loaded to check
    ///     against — is fine, because the pre-Zola `stage-site` pass synthesises
    ///     the web definition just as the PDF pipeline does. An UNKNOWN but
    ///     well-formed id is still critical: a typo would render as dead text on
    ///     the web (mirrors the unknown-id rule in `reviewShortcodes`).
    fn reviewDanglingRefs(self: *const ControlJoin, alloc: Allocator, path: []const u8, content: []const u8, native_refs_ok: bool) Config.IssueKind {
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
            if (native_refs_ok) {
                // Native footnotes are accepted; only a well-formed id the
                // catalog does not know is a problem (a typo → dead web text).
                if (self.catalog) |*cat| {
                    if (!cat.map.contains(label)) {
                        ctrllog.warn(
                            "{s}: unknown SCF control id '{s}' in footnote reference '[^{s}]' (not in data/scf.json)",
                            .{ path, label, label },
                        );
                        worst = .critical;
                    }
                }
                continue;
            }
            ctrllog.warn(
                "{s}: raw footnote reference '[^{s}]' in the body; use the control(id=\"{s}\") shortcode so it resolves on both the website and the PDF, or enable [extra.policypress] control_footnotes",
                .{ path, label, label },
            );
            worst = .critical;
        }
        return worst;
    }

    /// Advisory: a *known* control id referenced inline in the body — via a
    /// `control(...)` shortcode, or (when `native_refs_ok`) a `[^ID]` footnote
    /// reference — that is NOT listed in this policy's `taxonomies.SCF`. Coverage
    /// (the SCF report, the coverage annex, the audit bundle) is driven by the
    /// front-matter tags alone, so such a mention renders but silently does not
    /// count toward coverage; the author likely meant to tag it. Non-fatal,
    /// because referencing a control another policy owns is legitimate.
    ///
    /// Scoped to known ids with a catalog present: without a catalog there is no
    /// coverage report to match, and an unknown id is already flagged critical by
    /// `reviewShortcodes` / `reviewDanglingRefs`, so it is not re-reported here.
    /// Footnote references are considered only when native footnotes are enabled;
    /// otherwise a `[^ID]` is a dangling-ref critical handled separately.
    fn reviewInlineCoverage(self: *const ControlJoin, alloc: Allocator, path: []const u8, content: []const u8, native_refs_ok: bool) Config.IssueKind {
        const cat = if (self.catalog) |*c| c else return .none;

        var fm = zigmark.Frontmatter.initFromMarkdown(alloc, content) catch return .none;
        defer fm.deinit();

        // The set of front-matter SCF tags (borrowed; fm outlives this function).
        var tagged = std.StringHashMap(void).init(alloc);
        defer tagged.deinit();
        if (fm.get("taxonomies.SCF")) |scf| {
            if (scf == .array) {
                for (scf.array.items) |item| {
                    if (item == .string) tagged.put(item.string, {}) catch {};
                }
            }
        }

        // Ids already advised, so a control referenced twice warns once. Keys are
        // owned (some come from freed dangling-label slices).
        var advised = std.StringHashMap(void).init(alloc);
        defer {
            var kit = advised.keyIterator();
            while (kit.next()) |k| alloc.free(k.*);
            advised.deinit();
        }

        var worst: Config.IssueKind = .none;

        // Shortcode references: `{{ control(id="…") }}` (still `{{ … }}` text here).
        const strict: mvzr.Regex = mvzr.compile("\\{\\{\\s*control\\(id=\"[A-Z]{2,5}-[0-9]{2}(\\.[0-9]+)*\"\\)\\s*\\}\\}").?;
        var it = strict.iterator(content);
        while (it.next()) |m| {
            const key = "id=\"";
            const s = std.mem.indexOf(u8, m.slice, key) orelse continue;
            const id_start = s + key.len;
            const id_end = std.mem.indexOfScalarPos(u8, m.slice, id_start, '"') orelse continue;
            worst = maxKind(worst, considerInlineId(alloc, path, cat, &tagged, &advised, m.slice[id_start..id_end]));
        }

        // Native footnote references — only when they are an accepted form.
        if (native_refs_ok) {
            var parser = zigmark.Parser.init();
            defer parser.deinit(alloc);
            if (parser.parseMarkdown(alloc, content)) |doc_val| {
                var doc = doc_val;
                defer doc.deinit(alloc);
                if (zigmark.footnotes.dangling(alloc, &doc)) |dangs| {
                    defer {
                        for (dangs) |d| alloc.free(d);
                        alloc.free(dangs);
                    }
                    for (dangs) |label| {
                        worst = maxKind(worst, considerInlineId(alloc, path, cat, &tagged, &advised, label));
                    }
                } else |_| {}
            } else |_| {}
        }
        return worst;
    }

    /// `extra.scope_exclusions` validation. Each entry is `{ id, reason }`. An
    /// exclusion is a documented "we do not do X", so it must never read as
    /// coverage — the rules keep exclusions well-formed and surface the
    /// governance tension when a control is both covered and excluded:
    ///
    ///   * a malformed or (with a catalog) unknown id → critical;
    ///   * a missing/empty `reason` → critical;
    ///   * an id in *this* policy's `taxonomies.SCF` and its exclusions → critical
    ///     (a policy cannot both claim and disclaim the same control); and
    ///   * an id excluded here but covered by *another* published policy →
    ///     advisory (repo-wide view via the shared library).
    fn reviewExclusions(self: *const ControlJoin, alloc: Allocator, path: []const u8, content: []const u8) Config.IssueKind {
        var fm = zigmark.Frontmatter.initFromMarkdown(alloc, content) catch return .none;
        defer fm.deinit();

        const ex_v = fm.get("extra.scope_exclusions") orelse return .none;
        if (ex_v != .array) {
            ctrllog.warn("{s}: extra.scope_exclusions must be a list of {{ id, reason }} entries", .{path});
            return .critical;
        }

        // This policy's own SCF tags, for the same-policy cover+exclude check.
        const scf_v = fm.get("taxonomies.SCF");
        const own_title: []const u8 = blk: {
            if (fm.get("title")) |t| {
                if (t == .string) break :blk t.string;
            }
            break :blk path;
        };

        var worst: Config.IssueKind = .none;
        for (ex_v.array.items) |item| {
            if (item != .object) {
                ctrllog.warn("{s}: each extra.scope_exclusions entry must be a mapping with 'id' and 'reason'", .{path});
                worst = .critical;
                continue;
            }
            const obj = item.object;

            const id: ?[]const u8 = if (obj.get("id")) |v| (if (v == .string) v.string else null) else null;
            if (id == null) {
                ctrllog.warn("{s}: a scope-exclusion entry is missing a string 'id'", .{path});
                worst = .critical;
                continue;
            }
            const eid = id.?;

            if (!isControlId(eid)) {
                ctrllog.warn("{s}: malformed scope-exclusion id '{s}' (expected e.g. PES-01)", .{ path, eid });
                worst = .critical;
            } else if (self.catalog) |*cat| {
                if (!cat.map.contains(eid)) {
                    ctrllog.warn("{s}: unknown scope-exclusion id '{s}' (not in data/scf.json)", .{ path, eid });
                    worst = .critical;
                }
            }

            // A reason is mandatory: an unexplained exclusion is worthless to an
            // auditor and easy to mistake for an oversight.
            const reason_ok = blk: {
                const r = obj.get("reason") orelse break :blk false;
                if (r != .string) break :blk false;
                break :blk std.mem.trim(u8, r.string, " \t\r\n").len > 0;
            };
            if (!reason_ok) {
                ctrllog.warn("{s}: scope-exclusion '{s}' needs a non-empty 'reason'", .{ path, eid });
                worst = .critical;
            }

            // Same-policy cover+exclude: contradictory.
            if (scf_v) |sv| {
                if (sv == .array) {
                    for (sv.array.items) |t| {
                        if (t == .string and std.mem.eql(u8, t.string, eid)) {
                            ctrllog.warn(
                                "{s}: control '{s}' is listed in both taxonomies.SCF and extra.scope_exclusions — a policy cannot both claim and disclaim a control",
                                .{ path, eid },
                            );
                            worst = .critical;
                            break;
                        }
                    }
                }
            }

            // Cross-policy cover/exclude conflict → advisory. Only meaningful for
            // well-formed ids; a covering policy other than this one is the tension.
            if (isControlId(eid)) {
                const covering = self.coveringPolicies(alloc, eid, null) catch &.{};
                defer alloc.free(covering);
                for (covering) |title| {
                    if (!std.mem.eql(u8, title, own_title)) {
                        ctrllog.warn(
                            "{s}: control '{s}' is declared out of scope here but covered by '{s}' — praxis should adjudicate this governance tension",
                            .{ path, eid, title },
                        );
                        worst = maxKind(worst, .advisory);
                        break;
                    }
                }
            }
        }
        return worst;
    }
};

fn lessThanStr(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

/// Advise (once) on one inline-referenced control id: emit an advisory when it is
/// a known catalog control that is not in the policy's `taxonomies.SCF`. Returns
/// `.advisory` if it warned, else `.none`. `advised` dedups across the shortcode
/// and footnote passes (keys owned by the caller's map). See `reviewInlineCoverage`.
fn considerInlineId(
    alloc: Allocator,
    path: []const u8,
    cat: *const reports,
    tagged: *const std.StringHashMap(void),
    advised: *std.StringHashMap(void),
    id: []const u8,
) Config.IssueKind {
    if (!isControlId(id)) return .none;
    if (!cat.map.contains(id)) return .none; // unknown id: flagged critical elsewhere
    if (tagged.contains(id)) return .none; // tagged → already counts toward coverage
    if (advised.contains(id)) return .none; // warn once per id
    const key = alloc.dupe(u8, id) catch return .none;
    advised.put(key, {}) catch {
        alloc.free(key);
        return .none;
    };
    ctrllog.warn(
        "{s}: control '{s}' is referenced inline but not listed in taxonomies.SCF; it renders but does not count toward coverage. Add it to taxonomies.SCF to include it in the coverage report.",
        .{ path, id },
    );
    return .advisory;
}

/// A per-document `zigmark.footnotes.Resolver` context: a borrowed
/// `*const ControlJoin` plus the path of the policy currently being compiled.
/// The resolver's opaque `ctx` is a single pointer, so this small struct is the
/// per-document ctx — one is built (on the stack) per concurrent compile task,
/// bound to that task's policy, so "See also" can exclude the owning document
/// without any shared mutable state. Build via `ControlJoin.docResolver`.
pub const DocResolver = struct {
    join: *const ControlJoin,
    /// Path (relative to `config.root`) of the policy being compiled, excluded
    /// from its own "See also" cross-references. Null lists every covering
    /// policy (document-agnostic).
    self_path: ?[]const u8,

    /// The `zigmark.footnotes.Resolver` view. Borrows `self`; the `DocResolver`
    /// must outlive every use of the returned resolver.
    pub fn resolver(self: *const DocResolver) zigmark.footnotes.Resolver {
        return .{ .ctx = @constCast(self), .resolveFn = resolveThunk };
    }

    fn resolveThunk(ctx: ?*anyopaque, alloc: Allocator, label: []const u8) anyerror!?[]const u8 {
        const self: *const DocResolver = @ptrCast(@alignCast(ctx.?));
        return self.join.resolveFootnote(alloc, label, self.self_path);
    }
};

/// The one praxis touch in this core module: a load-time diagnostic warning
/// when the configured catalog and praxis join were built from different SCF
/// versions (a spine id the local catalog does not know cannot be titled).
/// Advisory only — it logs and never shapes rendered output, so a praxis-free
/// build (no join) never reaches it. Quarantined here so `resolveFootnote` and
/// the rest of `ControlJoin` stay praxis-agnostic (#174).
fn checkPraxisCatalogSkew(join: praxis_join.PraxisJoin, catalog: ?*const reports) void {
    const cat = catalog orelse return;
    for (join.ids) |id| {
        if (!cat.map.contains(id)) {
            ctrllog.warn(
                "praxis spine id '{s}' is not in the local control catalog (SCF version skew)",
                .{id},
            );
        }
    }
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

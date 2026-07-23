//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//!
//! Audit bundle (#135): a machine-readable, self-describing export of the
//! compliance state, written alongside the PDFs so an auditor or automated
//! evidence collector can consume it without scraping the site or the PDFs.
//!
//!   manifest.json   one entry per published policy: title, version, review
//!                   date, owner, approver, classification, PDF filename, and
//!                   sha-256 of both the PDF bytes (verify the file in hand)
//!                   and the Markdown source (stable across Typst churn)
//!   revisions.json  every policy's extra.major_revisions, flattened
//!   coverage.json   structured SCF + SOC 2 (TSC 2017) control coverage,
//!   coverage.csv    same numerator as the website and the report PDFs
//!
//! Opt-in (`--audit-bundle` / `[extra.policypress] audit_bundle`); the default
//! build output is unchanged. Deterministic: policies sorted by source path,
//! controls in catalog order, revisions in front-matter order.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;

const Config = @import("config").Config;
const u = @import("utils");
const zigmark = @import("zigmark");
const reports = @import("reports");

const log = std.log.scoped(.audit);

const schema_manifest = "policypress/audit-manifest/v1";
const schema_revisions = "policypress/audit-revisions/v1";
const schema_coverage = "policypress/audit-coverage/v1";
// The praxis join facet is a NEW file (join.json), so praxis's v1 coverage
// readers are untouched. It is written only when `config.praxis_join` is set.
const schema_join = "policypress/audit-join/v1";

const praxis_join = @import("praxis_join");

/// Write the three-file bundle into `audit_dir` (created if needed).
/// `pp_version` is the PolicyPress version stamped into the manifest.
/// Fails loudly when a manifest-listed PDF is missing from
/// `config.build_dir` — a manifest with holes is worse than no manifest
/// (stamp-fresh build with a deleted output dir; `nix run .#clean` resets).
pub fn writeBundle(
    io: std.Io,
    alloc: Allocator,
    config: Config,
    audit_dir: []const u8,
    pp_version: []const u8,
) !void {
    var arena_state = std.heap.ArenaAllocator.init(alloc);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    std.Io.Dir.cwd().createDirPath(io, audit_dir) catch |err| {
        log.err("cannot create audit directory '{s}': {s}", .{ audit_dir, @errorName(err) });
        return err;
    };

    const generated = try std.fmt.allocPrint(a, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        config.date.year, config.date.month, config.date.day,
    });

    // ── Walk policies (sorted; skip drafts and _index.md, matching the site) ─
    var pr = try std.Io.Dir.cwd().openDir(io, config.policy_dir, .{
        .access_sub_paths = true,
        .iterate = true,
    });
    defer pr.close(io);

    var files = std.ArrayList([]u8).empty;
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

    // The manifest's `pdf` field is prefixed with the output directory's
    // basename (normally "pdfs/") so a bundle consumer can resolve the file
    // relative to the site root, the same way the website links PDFs.
    const pdf_prefix = std.fs.path.basename(config.build_dir);

    var manifest_policies = std.json.Array.init(a);
    var revision_rows = std.json.Array.init(a);

    for (files.items) |path| {
        if (u.isDraftPolicy(io, a, pr, path)) continue;

        const source_bytes = try pr.readFileAlloc(io, path, a, .limited(u.max_policy_bytes));
        const source_sha = hexDigest(a, source_bytes) catch return error.OutOfMemory;

        var fm = zigmark.Frontmatter.initFromMarkdown(a, source_bytes) catch |e| {
            log.err("could not parse front matter of {s}; cannot build the audit bundle", .{path});
            return e;
        };
        defer fm.deinit();

        // The canonical PDF filename (with any redact/draft suffix for this
        // build variant) via the same helper the compiler and sweep use.
        var contents = std.ArrayList(u8){ .items = source_bytes, .capacity = source_bytes.len };
        var meta = try u.get_metadata(a, &contents, config);
        defer meta.deinit(a);
        const pdf_name = try meta.filename(a);

        const pdf_path = try std.fs.path.join(a, &.{ config.build_dir, pdf_name });
        const pdf_bytes = std.Io.Dir.cwd().readFileAlloc(io, pdf_path, a, .limited(256 * 1024 * 1024)) catch |err| {
            log.err(
                "audit bundle: PDF '{s}' for policy '{s}' is missing ({s}). " ++
                    "The manifest must describe every published PDF; rebuild from clean (nix run .#clean).",
                .{ pdf_path, path, @errorName(err) },
            );
            return error.AuditBundleMissingPdf;
        };
        const pdf_sha = hexDigest(a, pdf_bytes) catch return error.OutOfMemory;

        const title = stringAt(fm, "title") orelse path;
        const newest: ?std.json.ObjectMap = blk: {
            const revs = fm.get("extra.major_revisions") orelse break :blk null;
            if (revs != .array) break :blk null;
            break :blk u.newestRevision(revs.array.items);
        };

        var entry: std.json.ObjectMap = .empty;
        try entry.put(a, "source", .{ .string = try a.dupe(u8, path) });
        try entry.put(a, "title", .{ .string = try a.dupe(u8, title) });
        try entry.put(a, "version", try jsonString(a, if (newest) |o| valueString(a, o.get("version")) else null));
        try entry.put(a, "last_reviewed", try jsonString(a, stringAt(fm, "extra.last_reviewed")));
        try entry.put(a, "owner", try jsonString(a, stringAt(fm, "extra.owner")));
        try entry.put(a, "approved_by", try jsonString(a, if (newest) |o| valueString(a, o.get("approved_by")) else null));
        try entry.put(a, "classification", .{ .string = try a.dupe(u8, stringAt(fm, "extra.classification") orelse config.classification) });
        try entry.put(a, "pdf", .{ .string = try std.fmt.allocPrint(a, "{s}/{s}", .{ pdf_prefix, pdf_name }) });
        try entry.put(a, "pdf_sha256", .{ .string = pdf_sha });
        try entry.put(a, "source_sha256", .{ .string = source_sha });
        try manifest_policies.append(.{ .object = entry });

        // ── Flattened revision history ───────────────────────────────────────
        if (fm.get("extra.major_revisions")) |revs| {
            if (revs == .array) for (revs.array.items) |rev| {
                const obj = switch (rev) {
                    .object => |o| o,
                    else => continue,
                };
                var row: std.json.ObjectMap = .empty;
                try row.put(a, "policy", .{ .string = try a.dupe(u8, path) });
                try row.put(a, "title", .{ .string = try a.dupe(u8, title) });
                inline for (.{ "version", "date", "description", "revised_by", "approved_by" }) |field| {
                    try row.put(a, field, try jsonString(a, valueString(a, obj.get(field))));
                }
                try revision_rows.append(.{ .object = row });
            };
        }
    }

    // ── manifest.json ─────────────────────────────────────────────────────────
    {
        var build_obj: std.json.ObjectMap = .empty;
        try build_obj.put(a, "draft", .{ .bool = config.is_draft });
        try build_obj.put(a, "redact", .{ .bool = config.redact });

        var root: std.json.ObjectMap = .empty;
        try root.put(a, "schema", .{ .string = schema_manifest });
        try root.put(a, "generated_at", .{ .string = generated });
        try root.put(a, "policypress_version", .{ .string = pp_version });
        try root.put(a, "organization", .{ .string = config.org });
        try root.put(a, "base_url", .{ .string = config.base_url });
        try root.put(a, "build", .{ .object = build_obj });
        try root.put(a, "hash_algorithm", .{ .string = "sha256" });
        try root.put(a, "policies", .{ .array = manifest_policies });
        try writeJson(io, a, audit_dir, "manifest.json", .{ .object = root });
    }

    // ── revisions.json ────────────────────────────────────────────────────────
    {
        var root: std.json.ObjectMap = .empty;
        try root.put(a, "schema", .{ .string = schema_revisions });
        try root.put(a, "generated_at", .{ .string = generated });
        try root.put(a, "revisions", .{ .array = revision_rows });
        try writeJson(io, a, audit_dir, "revisions.json", .{ .object = root });
    }

    // ── coverage.json + coverage.csv ─────────────────────────────────────────
    // The SCF coverage is captured for reuse by the praxis join facet below;
    // its rows (declared_by / excluded_by, in catalog order) are exactly the
    // per-control data join.json needs. Backed by the catalog arena, itself
    // backed by `a`, so it stays valid until writeBundle returns.
    var scf_cov: ?reports.Coverage = null;
    {
        var frameworks = std.json.Array.init(a);
        var csv: std.Io.Writer.Allocating = .init(a);
        try csv.writer.writeAll("framework,control_id,domain,control,covered,policies,excluded_by\n");

        inline for (.{ reports.Kind.scf, reports.Kind.soc2 }) |kind| {
            const framework_id = switch (kind) {
                .scf => "SCF",
                .soc2 => "TSC2017",
                else => unreachable,
            };
            const catalog_rel = kind.catalogFile().?;
            const catalog_path = try std.fs.path.join(a, &.{ config.root, catalog_rel });
            const accessible = if (std.Io.Dir.cwd().access(io, catalog_path, .{})) |_| true else |_| false;
            if (!accessible) {
                log.info("audit bundle: control catalog '{s}' not found; skipping {s} coverage", .{ catalog_rel, framework_id });
            } else {
                // No deinit: the JSON tree below borrows catalog/coverage
                // strings, which must stay alive until writeJson stringifies
                // the whole document after this loop. The catalog's arena is
                // backed by the bundle arena `a`, which reclaims everything
                // when writeBundle returns.
                var catalog = try reports.init(io, a, catalog_path);
                const cov = try catalog.coverage(io, kind.taxonomyKey().?, config.policy_dir);
                if (kind == .scf) scf_cov = cov;

                var controls = std.json.Array.init(a);
                for (cov.controls) |c| {
                    var obj: std.json.ObjectMap = .empty;
                    try obj.put(a, "control_id", .{ .string = c.control_id });
                    try obj.put(a, "domain", .{ .string = c.domain });
                    try obj.put(a, "control", .{ .string = c.control });
                    try obj.put(a, "covered", .{ .bool = c.policies.len > 0 });
                    var pols = std.json.Array.init(a);
                    for (c.policies) |p| try pols.append(.{ .string = p });
                    try obj.put(a, "policies", .{ .array = pols });
                    // Additive per-control field (#165). The schema string is
                    // unchanged (praxis exact-matches …/v1 and ignores unknown
                    // keys); an exclusion is neither coverage nor a silent gap.
                    var excl = std.json.Array.init(a);
                    for (c.excluded_by) |p| try excl.append(.{ .string = p });
                    try obj.put(a, "excluded_by", .{ .array = excl });
                    try controls.append(.{ .object = obj });

                    // CSV row (policies and exclusions each ;-joined).
                    try writeCsvField(&csv.writer, framework_id);
                    try csv.writer.writeByte(',');
                    try writeCsvField(&csv.writer, c.control_id);
                    try csv.writer.writeByte(',');
                    try writeCsvField(&csv.writer, c.domain);
                    try csv.writer.writeByte(',');
                    try writeCsvField(&csv.writer, c.control);
                    try csv.writer.writeAll(if (c.policies.len > 0) ",true," else ",false,");
                    const joined = try std.mem.join(a, "; ", c.policies);
                    try writeCsvField(&csv.writer, joined);
                    try csv.writer.writeByte(',');
                    const excl_joined = try std.mem.join(a, "; ", c.excluded_by);
                    try writeCsvField(&csv.writer, excl_joined);
                    try csv.writer.writeByte('\n');
                }

                var fw: std.json.ObjectMap = .empty;
                try fw.put(a, "id", .{ .string = framework_id });
                try fw.put(a, "source", .{ .string = catalog_rel });
                try fw.put(a, "total", .{ .integer = @intCast(cov.total) });
                try fw.put(a, "covered", .{ .integer = @intCast(cov.covered) });
                try fw.put(a, "controls", .{ .array = controls });
                try frameworks.append(.{ .object = fw });
            }
        }

        var root: std.json.ObjectMap = .empty;
        try root.put(a, "schema", .{ .string = schema_coverage });
        try root.put(a, "generated_at", .{ .string = generated });
        try root.put(a, "frameworks", .{ .array = frameworks });
        try writeJson(io, a, audit_dir, "coverage.json", .{ .object = root });

        const csv_bytes = try csv.toOwnedSlice();
        try writeFile(io, a, audit_dir, "coverage.csv", csv_bytes);
    }

    // ── audit/join.json (praxis join facet) ──────────────────────────────────
    // Written ONLY when a praxis join is configured; when it is absent the
    // bundle is exactly as before this facet existed.
    try writeJoinFacet(io, a, config, audit_dir, generated, scf_cov);

    log.info("audit bundle written to '{s}' ({d} policies).", .{ audit_dir, manifest_policies.items.len });
}

/// Write `audit/join.json` (schema `policypress/audit-join/v1`) — the
/// policy↔praxis cross-check as a first-class facet, so praxis and auditors can
/// consume it directly instead of recomputing it from coverage.json. A NEW
/// file: praxis's coverage/v1 readers are untouched.
///
/// Returns immediately (writing nothing) when `config.praxis_join` is unset, so
/// the rest of the bundle is unchanged for sites without a join.
///
/// `controls` rows are the union of (praxis spine ids) ∪ (SCF-tagged ids) ∪
/// (excluded ids): every catalog control with coverage/exclusion data or spine
/// membership, in catalog order, followed by any spine id the local catalog
/// does not know (SCF version skew) in the join's sorted id order — fully
/// deterministic. `scf_cov` supplies the per-control declared_by / excluded_by.
fn writeJoinFacet(
    io: std.Io,
    a: Allocator,
    config: Config,
    audit_dir: []const u8,
    generated: []const u8,
    scf_cov: ?reports.Coverage,
) !void {
    const rel = config.praxis_join orelse return;

    // Resolve relative to the site root, matching how main.zig feeds the join
    // path to ControlJoin. A configured-but-unloadable join is a hard error —
    // silently dropping coverage data is worse than failing the build.
    const path = try std.fs.path.join(a, &.{ config.root, rel });
    var join = try praxis_join.PraxisJoin.load(io, a, path);
    defer join.deinit();

    var controls = std.json.Array.init(a);

    // Spine partition counts. Tie-break: a control that is BOTH covered and
    // excluded counts as covered (coverage precedes an exclusion), so the three
    // buckets stay disjoint and sum to the spine total.
    var spine_covered: usize = 0;
    var spine_excluded: usize = 0;
    var spine_unaddressed: usize = 0;

    // Spine ids already emitted as a catalog row, so the skew loop below never
    // double-counts one.
    var seen_spine: std.StringHashMapUnmanaged(void) = .empty;

    if (scf_cov) |cov| {
        for (cov.controls) |c| {
            const in_spine = join.contains(c.control_id);
            const covered = c.policies.len > 0;
            const excluded = c.excluded_by.len > 0;
            // Union filter: skip controls with no coverage, no exclusion, and no
            // spine membership — they are noise for a join view.
            if (!(in_spine or covered or excluded)) continue;

            var obj: std.json.ObjectMap = .empty;
            try obj.put(a, "id", .{ .string = c.control_id });
            try obj.put(a, "in_praxis_spine", .{ .bool = in_spine });
            var decl = std.json.Array.init(a);
            for (c.policies) |p| try decl.append(.{ .string = p });
            try obj.put(a, "declared_by", .{ .array = decl });
            var excl = std.json.Array.init(a);
            for (c.excluded_by) |p| try excl.append(.{ .string = p });
            try obj.put(a, "excluded_by", .{ .array = excl });
            // Cross-policy tension B4 flags as advisory: some policy claims the
            // control while another disclaims it (same-policy is a critical
            // validation error, so a conflict here is always cross-policy).
            try obj.put(a, "conflict", .{ .bool = covered and excluded });
            try controls.append(.{ .object = obj });

            if (in_spine) {
                try seen_spine.put(a, c.control_id, {});
                if (covered) {
                    spine_covered += 1;
                } else if (excluded) {
                    spine_excluded += 1;
                } else {
                    spine_unaddressed += 1;
                }
            }
        }
    }

    // Spine ids the local catalog does not carry: no coverage data exists, so
    // they are unaddressed. Appended after the catalog-ordered rows in the
    // join's (sorted) id order; deduped so a repeated join id counts once.
    for (join.ids) |id| {
        if (seen_spine.contains(id)) continue;
        try seen_spine.put(a, try a.dupe(u8, id), {});
        spine_unaddressed += 1;

        var obj: std.json.ObjectMap = .empty;
        try obj.put(a, "id", .{ .string = try a.dupe(u8, id) });
        try obj.put(a, "in_praxis_spine", .{ .bool = true });
        try obj.put(a, "declared_by", .{ .array = std.json.Array.init(a) });
        try obj.put(a, "excluded_by", .{ .array = std.json.Array.init(a) });
        try obj.put(a, "conflict", .{ .bool = false });
        try controls.append(.{ .object = obj });
    }

    // spine_total is the number of distinct spine ids; the loops above place
    // each in exactly one bucket, so the identity
    //   spine_covered + spine_excluded + spine_unaddressed == spine_total
    // holds by construction.
    const spine_total = join.id_set.count();

    var praxis_obj: std.json.ObjectMap = .empty;
    try praxis_obj.put(a, "generated_at", .{ .string = try a.dupe(u8, join.generated_at) });
    try praxis_obj.put(a, "source_rev", .{ .string = try a.dupe(u8, join.source_rev) });
    try praxis_obj.put(a, "scf_version", .{ .string = try a.dupe(u8, join.scf_version) });

    var summary: std.json.ObjectMap = .empty;
    try summary.put(a, "spine_total", .{ .integer = @intCast(spine_total) });
    try summary.put(a, "spine_covered", .{ .integer = @intCast(spine_covered) });
    try summary.put(a, "spine_excluded", .{ .integer = @intCast(spine_excluded) });
    try summary.put(a, "spine_unaddressed", .{ .integer = @intCast(spine_unaddressed) });

    var root: std.json.ObjectMap = .empty;
    try root.put(a, "schema", .{ .string = schema_join });
    try root.put(a, "generated_at", .{ .string = generated });
    try root.put(a, "praxis", .{ .object = praxis_obj });
    try root.put(a, "summary", .{ .object = summary });
    try root.put(a, "controls", .{ .array = controls });
    try writeJson(io, a, audit_dir, "join.json", .{ .object = root });

    log.info(
        "audit bundle: join.json written ({d} spine controls: {d} covered, {d} excluded, {d} unaddressed).",
        .{ spine_total, spine_covered, spine_excluded, spine_unaddressed },
    );
}

// ── helpers ───────────────────────────────────────────────────────────────────

fn lessThanString(_: void, lhs: []u8, rhs: []u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

/// Lower-case hex sha-256 of `bytes`, allocated from `a`.
fn hexDigest(a: Allocator, bytes: []const u8) ![]u8 {
    var digest: [Sha256.digest_length]u8 = undefined;
    Sha256.hash(bytes, &digest, .{});
    return std.fmt.allocPrint(a, "{x}", .{&digest});
}

fn stringAt(fm: zigmark.Frontmatter, key: []const u8) ?[]const u8 {
    const v = fm.get(key) orelse return null;
    return switch (v) {
        .string => |s| s,
        else => null,
    };
}

/// A frontmatter value normalised to a string (YAML numeric scalars like a
/// quoted "1.1" come back as floats in some parses), or null. The returned
/// slice may be borrowed from the Frontmatter; `jsonString` duplicates it.
fn valueString(a: Allocator, v: ?std.json.Value) ?[]const u8 {
    const val = v orelse return null;
    return switch (val) {
        .string => |s| s,
        .float => |f| std.fmt.allocPrint(a, "{d}", .{f}) catch null,
        .integer => |n| std.fmt.allocPrint(a, "{d}", .{n}) catch null,
        else => null,
    };
}

/// Wrap a string as a JSON value, duplicated into `a` (frontmatter strings
/// are freed per policy while the JSON tree is stringified afterwards), or
/// JSON null. Allocation failure is an error — a silently nulled
/// `approved_by` would misreport the compliance state.
fn jsonString(a: Allocator, s: ?[]const u8) !std.json.Value {
    const str = s orelse return .null;
    return .{ .string = try a.dupe(u8, str) };
}

/// Quote a CSV field when it contains a comma, quote, or newline (RFC 4180).
fn writeCsvField(w: *std.Io.Writer, field: []const u8) !void {
    const needs_quoting = std.mem.indexOfAny(u8, field, ",\"\n\r") != null;
    if (!needs_quoting) return w.writeAll(field);
    try w.writeByte('"');
    for (field) |c| {
        if (c == '"') try w.writeByte('"');
        try w.writeByte(c);
    }
    try w.writeByte('"');
}

fn writeJson(io: std.Io, a: Allocator, dir: []const u8, name: []const u8, value: std.json.Value) !void {
    const out = try std.json.Stringify.valueAlloc(a, value, .{ .whitespace = .indent_1 });
    const with_nl = try std.fmt.allocPrint(a, "{s}\n", .{out});
    try writeFile(io, a, dir, name, with_nl);
}

/// Write via a temp file + rename so a crash or full disk mid-write can never
/// leave a truncated bundle file behind — a manifest with holes would
/// under-report the compliance state while still looking present.
fn writeFile(io: std.Io, a: Allocator, dir: []const u8, name: []const u8, bytes: []const u8) !void {
    const tmp_path = try std.fs.path.join(a, &.{ dir, ".tmp.audit" });
    const final_path = try std.fs.path.join(a, &.{ dir, name });
    {
        const f = try std.Io.Dir.cwd().createFile(io, tmp_path, .{ .truncate = true });
        defer f.close(io);
        try f.writeStreamingAll(io, bytes);
    }
    try std.Io.Dir.cwd().rename(tmp_path, std.Io.Dir.cwd(), final_path, io);
}

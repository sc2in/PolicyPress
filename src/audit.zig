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
        try entry.put(a, "version", jsonString(a, if (newest) |o| valueString(a, o.get("version")) else null));
        try entry.put(a, "last_reviewed", jsonString(a, stringAt(fm, "extra.last_reviewed")));
        try entry.put(a, "owner", jsonString(a, stringAt(fm, "extra.owner")));
        try entry.put(a, "approved_by", jsonString(a, if (newest) |o| valueString(a, o.get("approved_by")) else null));
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
                    try row.put(a, field, jsonString(a, valueString(a, obj.get(field))));
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
    {
        var frameworks = std.json.Array.init(a);
        var csv: std.Io.Writer.Allocating = .init(a);
        try csv.writer.writeAll("framework,control_id,domain,control,covered,policies\n");

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
                var catalog = try reports.init(io, a, catalog_path);
                defer catalog.deinit();
                const cov = try catalog.coverage(io, kind.taxonomyKey().?, config.policy_dir);

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
                    try controls.append(.{ .object = obj });

                    // CSV row (policies ;-joined).
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
        try writeFileAtomic(io, audit_dir, "coverage.csv", csv_bytes);
    }

    log.info("audit bundle written to '{s}' ({d} policies).", .{ audit_dir, manifest_policies.items.len });
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
/// quoted "1.1" come back as floats in some parses), or null. Always
/// duplicated into `a`: quoted YAML scalars are freshly allocated strings
/// owned by the Frontmatter, which is deinited per policy while the JSON tree
/// is stringified afterwards.
fn valueString(a: Allocator, v: ?std.json.Value) ?[]const u8 {
    const val = v orelse return null;
    return switch (val) {
        .string => |s| a.dupe(u8, s) catch null,
        .float => |f| std.fmt.allocPrint(a, "{d}", .{f}) catch null,
        .integer => |n| std.fmt.allocPrint(a, "{d}", .{n}) catch null,
        else => null,
    };
}

/// Wrap an (already `a`-owned or duplicated) string, or JSON null.
fn jsonString(a: Allocator, s: ?[]const u8) std.json.Value {
    if (s) |str| {
        if (a.dupe(u8, str)) |copy| return .{ .string = copy } else |_| return .null;
    }
    return .null;
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
    try writeFileAtomic(io, dir, name, with_nl);
}

fn writeFileAtomic(io: std.Io, dir: []const u8, name: []const u8, bytes: []const u8) !void {
    const path = try std.fs.path.join(std.heap.page_allocator, &.{ dir, name });
    defer std.heap.page_allocator.free(path);
    const f = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer f.close(io);
    try f.writeStreamingAll(io, bytes);
}

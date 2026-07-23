//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//!
//! Loader for the praxis control-join file (`data/praxis-join.json`).
//!
//! praxis (a private GRC system) publishes a flat list of the bare SCF control
//! ids it actively governs — managed controls plus opt-in organizational
//! families. praxis cannot be a PolicyPress flake input (public repo ↔ private
//! GRC repo, and the feature must work for any consumer with their own
//! praxis-like list), so the list is materialised into a consumer-generated,
//! committed data file — mirroring the existing `scf` input → `data/scf.json`
//! pattern. `tools/gen-praxis-join.py` (flake app `.#gen-praxis-join`) writes
//! this file; `PraxisJoin.load` reads it back for the coverage surfaces added
//! by later subissues.
//!
//! This module is plumbing only: it loads and validates the file and answers
//! membership queries. It does not render anything, and an absent join file is
//! not this module's concern — callers simply skip loading, so every praxis
//! surface degrades gracefully when `config.praxis_join` is unset.

const std = @import("std");
const Allocator = std.mem.Allocator;
const tst = std.testing;

/// Schema string every join file must carry verbatim. A mismatch is a hard
/// error: silently accepting an unknown shape would let a future or foreign
/// format pass as coverage data.
pub const schema_id = "policypress/praxis-join/v1";

/// Errors distinct to the join file's contract. File-open and JSON-syntax
/// errors surface as their own std errors; these name the semantic failures a
/// caller acts on.
pub const Error = error{
    /// The file parsed as JSON but carried no top-level `schema` string.
    MissingSchema,
    /// A `schema` string was present but was not `schema_id`.
    SchemaMismatch,
    /// The top level was not a JSON object, or a field was of the wrong type.
    MalformedJoinFile,
};

/// A loaded, validated praxis join. Owns all of its memory via `arena`; the
/// exposed slices and set keys borrow from it, so the value must outlive any
/// reference and be released with `deinit`.
pub const PraxisJoin = struct {
    arena: std.heap.ArenaAllocator,
    /// Date the file was generated (YYYY-MM-DD), for the auditor-facing
    /// provenance later subissues surface. Empty when the file omits it.
    generated_at: []const u8,
    /// praxis revision the id list was produced from (`source.rev`). Empty when absent.
    source_rev: []const u8,
    /// SCF dataset version the ids were resolved against (`source.scf_version`).
    scf_version: []const u8,
    /// Opt-in organizational families the spine was built from, as written.
    organizational_families: []const []const u8,
    /// Flat list of bare SCF control ids in the praxis spine, in the generator's
    /// (sorted) order.
    ids: []const []const u8,
    /// Membership index over `ids` for O(1) `contains`; keys borrow from `ids`.
    id_set: std.StringArrayHashMapUnmanaged(void),

    /// Load and validate the join file at `path`, tried relative to cwd then as
    /// an absolute path (mirroring `control_report.zig`'s catalog open). The
    /// returned value owns all its memory — free it with `deinit`. A
    /// wrong/missing schema string is a hard, distinct error (`SchemaMismatch` /
    /// `MissingSchema`); a structurally broken file is `MalformedJoinFile`.
    pub fn load(io: std.Io, alloc: Allocator, path: []const u8) !PraxisJoin {
        var f = std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only }) catch |e| blk: {
            if (e == error.FileNotFound) break :blk std.Io.Dir.openFileAbsolute(io, path, .{ .mode = .read_only }) catch |e2| {
                std.debug.print("praxis join file not found: '{s}'\n", .{path});
                return e2;
            } else return e;
        };
        defer f.close(io);

        var arena = std.heap.ArenaAllocator.init(alloc);
        errdefer arena.deinit();
        const a = arena.allocator();

        var rbuf: [4096]u8 = undefined;
        var fr = f.reader(io, &rbuf);
        const content = try fr.interface.allocRemaining(a, .limited(4_000_000));

        const root = std.json.parseFromSliceLeaky(std.json.Value, a, content, .{}) catch |e| {
            std.debug.print("praxis join file '{s}' is not valid JSON: {s}\n", .{ path, @errorName(e) });
            return Error.MalformedJoinFile;
        };
        if (root != .object) {
            std.debug.print("praxis join file '{s}' must be a JSON object\n", .{path});
            return Error.MalformedJoinFile;
        }
        const obj = root.object;

        // Schema gate first: the one hard, distinct error callers branch on. An
        // unknown or missing schema must never be treated as coverage data.
        const schema_v = obj.get("schema") orelse {
            std.debug.print("praxis join file '{s}' has no 'schema' field (expected \"{s}\")\n", .{ path, schema_id });
            return Error.MissingSchema;
        };
        if (schema_v != .string) {
            std.debug.print("praxis join file '{s}' 'schema' must be a string (expected \"{s}\")\n", .{ path, schema_id });
            return Error.MissingSchema;
        }
        if (!std.mem.eql(u8, schema_v.string, schema_id)) {
            std.debug.print("praxis join file '{s}' has schema \"{s}\"; expected \"{s}\"\n", .{ path, schema_v.string, schema_id });
            return Error.SchemaMismatch;
        }

        // Provenance. Absent subfields default to "" so callers always get a
        // string; the file is generated, so this is belt-and-suspenders.
        const generated_at = stringField(obj, "generated_at") orelse "";
        var source_rev: []const u8 = "";
        var scf_version: []const u8 = "";
        if (obj.get("source")) |src| {
            if (src == .object) {
                source_rev = stringField(src.object, "rev") orelse "";
                scf_version = stringField(src.object, "scf_version") orelse "";
            }
        }

        const families = try stringArray(a, obj, "organizational_families");
        const ids = try stringArray(a, obj, "ids");

        var id_set: std.StringArrayHashMapUnmanaged(void) = .empty;
        for (ids) |id| try id_set.put(a, id, {});

        return .{
            .arena = arena,
            .generated_at = generated_at,
            .source_rev = source_rev,
            .scf_version = scf_version,
            .organizational_families = families,
            .ids = ids,
            .id_set = id_set,
        };
    }

    pub fn deinit(self: *PraxisJoin) void {
        self.arena.deinit();
    }

    /// Whether `id` is in the praxis spine. Never allocates.
    pub fn contains(self: *const PraxisJoin, id: []const u8) bool {
        return self.id_set.contains(id);
    }
};

/// A string-valued field, or null when the key is absent or not a string.
fn stringField(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const v = obj.get(key) orelse return null;
    return switch (v) {
        .string => |s| s,
        else => null,
    };
}

/// Collect a JSON array of strings into a slice owned by `a`. A missing key
/// yields an empty slice (a partial file is tolerated for forward
/// compatibility); a present value that is not an array of strings is a hard
/// `MalformedJoinFile` error. Strings borrow from the parsed tree, which the
/// caller's arena owns.
fn stringArray(a: Allocator, obj: std.json.ObjectMap, key: []const u8) ![]const []const u8 {
    const v = obj.get(key) orelse return &.{};
    if (v != .array) return Error.MalformedJoinFile;
    const out = try a.alloc([]const u8, v.array.items.len);
    for (v.array.items, 0..) |item, i| {
        if (item != .string) return Error.MalformedJoinFile;
        out[i] = item.string;
    }
    return out;
}

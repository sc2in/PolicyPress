//! Shared helper for the golden Typst-markup snapshots. Both the golden test
//! (golden_test.zig at the repo root) and the regenerator (tools/golden_gen.zig)
//! render a fixture through this so the committed baselines and the check use
//! byte-for-byte the same path.
//!
//! Determinism: the footer year (config.current_year) and config.date are the
//! only wall-clock inputs to the rendered markup, so both are pinned here. Logo
//! and draft-watermark paths are root-relative and committed; mermaid SVG is
//! pure pozeiden (golden-tested upstream).

const std = @import("std");
const Config = @import("config").Config;
const typst = @import("typst");

pub const Mode = enum { plain, redact, draft };

/// Minimal config accepted by Config.load. redact_web is irrelevant to PDF
/// rendering; the fixtures live under src/test, reached via config.root.
const golden_config =
    \\base_url = "http://localhost:1111"
    \\[extra.policypress]
    \\redact_web = false
    \\policy_dir = "src/test"
    \\organization = "Star City Security Consulting"
    \\logo = "logo.png"
    \\pdf_color = "#0e90f3"
;

/// Render `fixture` (a path relative to the repo root, e.g.
/// "src/test/test_policy.md") to Typst markup under a pinned, deterministic
/// config. Caller owns the returned slice.
pub fn renderFixture(io: std.Io, alloc: std.mem.Allocator, fixture: []const u8, mode: Mode) ![]u8 {
    var conf = try Config.load(io, alloc, golden_config);
    defer conf.deinit(alloc);

    // Pin the only wall-clock inputs so the markup never drifts by date.
    conf.date = .{ .year = 2026, .month = 1, .day = 1 };
    conf.current_year = 2026;
    conf.redact = (mode == .redact);
    conf.is_draft = (mode == .draft);

    var rendered = try typst.render(io, alloc, conf, fixture);
    defer rendered.deinit(alloc);
    return alloc.dupe(u8, rendered.source);
}

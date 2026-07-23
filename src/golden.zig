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
const reports = @import("reports");
const controls = @import("controls");

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

/// Render the control-footnote fixture with a fixture-backed `ControlJoin`
/// context (small committed catalog + join under src/test, and the fixture
/// itself as the sole library policy). Proves that inline `control(...)`
/// references become native `#footnote[…]` with the resolved title / spine /
/// covering-policy text. Fully deterministic. Caller owns the slice.
pub fn renderControlFixture(io: std.Io, alloc: std.mem.Allocator) ![]u8 {
    var conf = try Config.load(io, alloc, golden_config);
    defer conf.deinit(alloc);
    conf.date = .{ .year = 2026, .month = 1, .day = 1 };
    conf.current_year = 2026;

    const fixture = "src/test/test_policy_controls.md";
    var cj = try controls.ControlJoin.init(
        io,
        alloc,
        "src/test/controls_catalog.json",
        "src/test/controls_join.json",
        &.{fixture},
    );
    defer cj.deinit();

    var rendered = try typst.renderWithControls(io, alloc, conf, fixture, cj.resolver());
    defer rendered.deinit(alloc);
    return alloc.dupe(u8, rendered.source);
}

/// Render one report kind from the tests/report-fixtures fixtures (catalog
/// JSONs + policies/) under fully pinned options. The fixtures live outside
/// src/test because the validation tests walk that whole tree and these
/// fixtures intentionally include invalid front matter (missing revisions,
/// unparseable dates). Caller owns the slice.
pub fn renderReportFixture(io: std.Io, alloc: std.mem.Allocator, kind: reports.Kind) ![]u8 {
    const opts: reports.render.ReportOpts = .{
        .title = kind.title(),
        .org = "Star City Security Consulting",
        .color = "0e90f3",
        .logo = null,
        .footer_left = "Star City Security Consulting \u{00a9} 2026",
        .classification = "Confidential",
        .generated = "2026-01-01",
        .review_overdue_days = 365,
    };
    const fixture_policies = "tests/report-fixtures/policies";
    switch (kind) {
        .scf, .soc2 => {
            const catalog_path = if (kind == .scf)
                "tests/report-fixtures/report_catalog_scf.json"
            else
                "tests/report-fixtures/report_catalog_tsc.json";
            var catalog = try reports.init(io, alloc, catalog_path);
            defer catalog.deinit();
            const cov = try catalog.coverage(io, kind.taxonomyKey().?, fixture_policies);
            return reports.render.renderCoverage(alloc, cov, opts);
        },
        .review => {
            const rows = try reports.collectReviewRows(io, alloc, fixture_policies, .{ .year = 2026, .month = 1, .day = 1 });
            defer reports.freeReviewRows(alloc, rows);
            return reports.render.renderReview(alloc, rows, opts);
        },
    }
}

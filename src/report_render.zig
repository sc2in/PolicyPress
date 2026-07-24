//! Copyright © 2026 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 OR PolyForm-Internal-Use-1.0.0
//!
//! Typst markup for the report PDFs (SCF/SOC 2 coverage, policy review).
//! Struct-driven — the data comes from control_report.zig, never zigmark —
//! and reuses the shared preamble (typst.writeDocSetup / writeTitlePage /
//! writeOutline) so the reports match the policy PDFs' look, fonts, and
//! PDF/UA-1 behaviour. Every interpolated string goes through the typst
//! escape helpers: catalog control names are data, not trusted markup.

const std = @import("std");
const Allocator = std.mem.Allocator;

const typst = @import("typst");

const report = @import("control_report.zig");

/// Document chrome shared by all reports, derived from Config by the caller
/// (main.zig) so this module stays free of config/file-system concerns.
pub const ReportOpts = struct {
    title: []const u8,
    org: []const u8,
    /// Already validated via typst.validatedColor.
    color: []const u8,
    /// Root-absolute Typst logo path (typst.resolveLogoPath), or null.
    logo: ?[]const u8,
    footer_left: []const u8,
    classification: []const u8,
    /// Build date shown as "Generated: YYYY-MM-DD" on the title page.
    generated: []const u8,
    /// Days after which a review is overdue (config.review_overdue_days).
    review_overdue_days: u32 = 365,
};

fn writeReportPreamble(writer: anytype, opts: ReportOpts) !void {
    try typst.writeDocSetup(writer, .{
        .title = opts.title,
        .header_title = opts.title,
        .author = opts.org,
        .logo = opts.logo,
        .footer_left = opts.footer_left,
        .footer_center = opts.classification,
    });
    try typst.writeTitlePage(writer, .{
        .title = opts.title,
        .version = null,
        .color = opts.color,
        .author = opts.org,
        .logo = opts.logo,
        .date_label = "Generated: ",
        .date_value = opts.generated,
    });
    try typst.writeOutline(writer);
}

/// Render a coverage report (SCF or SOC 2) to complete Typst source.
/// Caller owns the returned slice.
pub fn renderCoverage(alloc: Allocator, cov: report.Coverage, opts: ReportOpts) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(alloc);
    defer aw.deinit();
    const w = &aw.writer;

    try writeReportPreamble(w, opts);

    // ── Summary ──────────────────────────────────────────────────────────────
    // Same numerator as the website (#129): distinct catalog controls with at
    // least one mapped policy over the catalog total.
    const pct: u64 = if (cov.total == 0) 0 else (cov.covered * 100 + cov.total / 2) / cov.total;
    try w.writeAll("= Summary\n\n");
    try w.print(
        "*{d}* of *{d}* controls ({d}%) are covered by at least one published policy.\n\n",
        .{ cov.covered, cov.total, pct },
    );
    // Sections are separated by a leading "\n" (not a trailing "\n\n") so the
    // rendered file ends in exactly one newline — golden baselines are
    // committed and the repo's end-of-file fixer would otherwise trim them
    // out of sync with the generated markup.
    try w.writeAll(
        "Coverage means a published policy lists the control in its front-matter " ++
            "taxonomy. Draft policies are excluded, matching the website.\n",
    );
    // Scope exclusions are a distinct third state: a documented "we do not do
    // this", counted apart from coverage. Emitted only when present, so reports
    // with no exclusions (e.g. SOC 2, whose criteria are never excluded by the
    // SCF-id exclusion list) stay byte-identical.
    if (cov.excluded > 0) {
        try w.print(
            "\n*{d}* control(s) are declared out of scope by a published policy; " ++
                "an exclusion is a documented decision not to apply a control and is " ++
                "counted separately from coverage.\n",
            .{cov.excluded},
        );
    }

    // ── Per-domain sections (catalog order; domains are contiguous runs) ────
    var i: usize = 0;
    while (i < cov.controls.len) {
        const domain = cov.controls[i].domain;
        var end = i;
        var dom_covered: usize = 0;
        while (end < cov.controls.len and std.mem.eql(u8, cov.controls[end].domain, domain)) : (end += 1) {
            if (cov.controls[end].policies.len > 0) dom_covered += 1;
        }

        try w.writeAll("\n= ");
        try typst.writeEscaped(w, domain);
        try w.writeAll("\n\n");
        try w.print("{d} of {d} controls covered.\n\n", .{ dom_covered, end - i });

        try w.writeAll(
            "#table(\n" ++
                "  columns: (auto, 1fr, 1fr),\n" ++
                "  align: (left, left, left),\n" ++
                "  table.header(\n" ++
                "    [*Control*], [*Name*], [*Covering Policies*],\n" ++
                "  ),\n",
        );
        while (i < end) : (i += 1) {
            const c = cov.controls[i];
            try w.writeAll("  [");
            try typst.writeEscaped(w, c.control_id);
            try w.writeAll("], [");
            try typst.writeEscaped(w, std.mem.trim(u8, c.control, " "));
            try w.writeAll("], [");
            if (c.policies.len == 0 and c.excluded_by.len == 0) {
                try w.writeAll("\u{2014}");
            } else {
                for (c.policies, 0..) |p, pi| {
                    if (pi > 0) try w.writeAll("; ");
                    try typst.writeEscaped(w, p);
                }
                // Distinct marker for a declared-out-of-scope control, appended
                // after any covering policies (a control can, in a governance
                // conflict, be both covered and excluded).
                if (c.excluded_by.len > 0) {
                    if (c.policies.len > 0) try w.writeAll("; ");
                    try w.writeAll("out of scope: ");
                    for (c.excluded_by, 0..) |p, pi| {
                        if (pi > 0) try w.writeAll(", ");
                        try typst.writeEscaped(w, p);
                    }
                }
            }
            try w.writeAll("],\n");
        }
        try w.writeAll(")\n");
    }

    return aw.toOwnedSlice();
}

/// Render the policy-review report to complete Typst source. Caller owns the
/// returned slice.
pub fn renderReview(alloc: Allocator, rows: []const report.ReviewRow, opts: ReportOpts) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(alloc);
    defer aw.deinit();
    const w = &aw.writer;

    try writeReportPreamble(w, opts);

    var overdue: usize = 0;
    for (rows) |r| {
        if (r.days_since) |d| {
            if (d > opts.review_overdue_days) overdue += 1;
        }
    }

    try w.writeAll("= Summary\n\n");
    try w.print(
        "*{d}* published policies; *{d}* overdue for review " ++
            "(last reviewed more than {d} days before this report was generated).\n\n",
        .{ rows.len, overdue, opts.review_overdue_days },
    );

    try w.writeAll("= Review Status\n\n");
    try w.writeAll(
        "#table(\n" ++
            "  columns: (1fr, auto, auto, auto, auto),\n" ++
            "  align: (left, center, left, center, center),\n" ++
            "  table.header(\n" ++
            "    [*Policy*], [*Version*], [*Owner*], [*Last Reviewed*], [*Status*],\n" ++
            "  ),\n",
    );
    for (rows) |r| {
        try w.writeAll("  [");
        try typst.writeEscaped(w, r.title);
        try w.writeAll("], [");
        if (r.version.len > 0) {
            try w.writeAll("v");
            try typst.writeEscaped(w, r.version);
        }
        try w.writeAll("], [");
        if (r.owner) |o| try typst.writeEscaped(w, o) else try w.writeAll("\u{2014}");
        try w.writeAll("], [");
        try typst.writeEscaped(w, r.last_reviewed);
        try w.writeAll("], ");
        try writeStatusCell(w, r.days_since, opts.review_overdue_days);
        try w.writeAll(",\n");
    }
    try w.writeAll(")\n");

    return aw.toOwnedSlice();
}

/// Status cell: Current / Due soon (within 90 days of the deadline) / Overdue,
/// with the website review-report's soft fills (never colour alone — the label
/// is the information, the fill is a reading aid).
fn writeStatusCell(w: anytype, days_since: ?i64, overdue_days: u32) !void {
    const days = days_since orelse {
        return w.writeAll("[Unknown]");
    };
    const deadline: i64 = overdue_days;
    if (days > deadline) {
        try w.writeAll("table.cell(fill: rgb(\"#f09d9d\"))[Overdue]");
    } else if (days > deadline - 90) {
        try w.writeAll("table.cell(fill: rgb(\"#e2bc76\"))[Due soon]");
    } else {
        try w.writeAll("table.cell(fill: rgb(\"#a2dea2\"))[Current]");
    }
}

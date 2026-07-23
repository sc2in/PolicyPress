//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//!
//! Plain data contract for the PDF "Control Coverage" annex (#127 / #165).
//!
//! Frontmatter control/criterion tags (`taxonomies.SCF`, `taxonomies.TSC2017`)
//! and scope exclusions (`extra.scope_exclusions`) have no in-text anchor, so —
//! unlike inline `control(...)` references, which become footnotes — they are
//! rendered as an annex table at the end of a policy PDF.
//!
//! `typst.zig` reads the per-policy tags straight from the frontmatter it
//! already parses, and asks a `Provider` only the one *global* question that
//! needs the framework catalog: a control's title. The provider's `ctx` is an
//! opaque pointer to the `controls.ControlJoin` (populated by
//! `ControlJoin.annexProvider`), so `typst.zig` never imports `controls` — the
//! same module-cycle discipline B3 used for the footnote resolver. Read-only
//! after construction, so one provider value is shared across the concurrent
//! per-policy compile tasks.
//!
//! The annex is deliberately praxis-agnostic: praxis-spine membership is an
//! optional overlay surfaced via the web badges and `audit/join.json`, never
//! baked into this core table (#127 follow-up).
//!
//! This module has no dependencies beyond `std`, so both `typst.zig` (the
//! consumer) and `controls.zig` (the producer) can import it without a cycle.

const std = @import("std");

/// The two report-backed frameworks a policy can tag. Kept minimal on purpose:
/// only these two get a coverage annex table (ID | Control/Criterion).
pub const Framework = enum { scf, tsc2017 };

/// Global display info for one control/criterion id, resolved from the catalog.
pub const Info = struct {
    /// Human title from the framework catalog, or null when no catalog is loaded
    /// or the id is unknown (the annex then shows the id alone). Borrows from the
    /// catalog's arena, which outlives every render.
    title: ?[]const u8 = null,
};

/// A resolver for the annex's title lookup, bound to a `controls.ControlJoin`.
/// Passed by value into the typst render path alongside the footnote resolver.
pub const Provider = struct {
    ctx: ?*anyopaque = null,
    lookupFn: *const fn (ctx: ?*anyopaque, framework: Framework, id: []const u8) Info,

    pub fn lookup(self: Provider, framework: Framework, id: []const u8) Info {
        return self.lookupFn(self.ctx, framework, id);
    }
};

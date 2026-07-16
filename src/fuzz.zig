//! Fuzz harness for PolicyPress's own parsing/validation/transform surfaces —
//! the code PolicyPress adds on top of its dependencies (zigmark/pozeiden/tomlz
//! are fuzzed in their own repos). Mirrors zigmark's harness layout.
//!
//! Run once (smoke test):       zig build fuzz
//! Coverage-guided fuzzing:     zig build fuzz --fuzz
//!
//! Targets take a `*std.testing.Smith` (the Zig 0.16 structured-input source)
//! and pull up to `max_input` bytes via `smith.slice`. Each uses a fresh arena
//! and asserts only the absence of crashes/UB/leaks, not correctness — every
//! expected error is swallowed with `catch return`.

const std = @import("std");
const config = @import("config");
const utils = @import("utils");
const zigmark = @import("zigmark");
const toml = @import("tomlz");

const Smith = std.testing.Smith;
const Array = std.ArrayList;
const max_input = 8192;

test "fuzz_config_toml" {
    try std.testing.fuzz({}, fuzzConfigToml, .{});
}

test "fuzz_frontmatter_review" {
    try std.testing.fuzz({}, fuzzFrontmatterReview, .{});
}

test "fuzz_find_raw_html" {
    try std.testing.fuzz({}, fuzzFindRawHtml, .{});
}

test "fuzz_redact" {
    try std.testing.fuzz({}, fuzzRedact, .{});
}

test "fuzz_shortcode_transforms" {
    try std.testing.fuzz({}, fuzzShortcodeTransforms, .{});
}

// ── Implementations ───────────────────────────────────────────────────────────

/// toml.parse over arbitrary bytes, then Config.validate over the result.
/// `validate` ignores its Config receiver, so an undefined one is safe.
fn fuzzConfigToml(_: void, smith: *Smith) anyerror!void {
    var buf: [max_input]u8 = undefined;
    const input = buf[0..smith.slice(&buf)];
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var table = toml.parse(alloc, input) catch return;
    defer table.deinit(alloc);
    var cfg: config.Config = undefined;
    cfg.validate(table) catch return;
}

/// Frontmatter parse + validateFrontMatter (which also ignores its receiver).
fn fuzzFrontmatterReview(_: void, smith: *Smith) anyerror!void {
    var buf: [max_input]u8 = undefined;
    const input = buf[0..smith.slice(&buf)];
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var fm = zigmark.Frontmatter.initFromMarkdown(arena.allocator(), input) catch return;
    defer fm.deinit();
    var cfg: config.Config = undefined;
    cfg.validateFrontMatter(fm) catch return;
}

/// The raw-HTML AST walk PolicyPress adds (src/config.zig).
fn fuzzFindRawHtml(_: void, smith: *Smith) anyerror!void {
    var buf: [max_input]u8 = undefined;
    const input = buf[0..smith.slice(&buf)];
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    _ = config.Config.findRawHtml(arena.allocator(), input) catch return;
}

/// redact() in both modes (mask / remove).
fn fuzzRedact(_: void, smith: *Smith) anyerror!void {
    var buf: [max_input]u8 = undefined;
    const input = buf[0..smith.slice(&buf)];
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    inline for (.{ true, false }) |remove| {
        var arr = Array(u8).empty;
        arr.appendSlice(alloc, input) catch return;
        utils.redact(alloc, &arr, remove) catch return;
    }
}

/// The shortcode-transform chain applied to every policy body, in order.
fn fuzzShortcodeTransforms(_: void, smith: *Smith) anyerror!void {
    var buf: [max_input]u8 = undefined;
    const input = buf[0..smith.slice(&buf)];
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var arr = Array(u8).empty;
    arr.appendSlice(alloc, input) catch return;
    utils.replace_org(alloc, &arr, "Org") catch return;
    utils.replace_zola_at(alloc, &arr, "https://example.com") catch return;
    utils.replace_mermaid(alloc, &arr) catch return;
    utils.replace_admonitions(alloc, &arr) catch return;
}

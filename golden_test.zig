//! Golden snapshots of the generated Typst markup. Renders each fixture through
//! the shared, date-pinned helper and compares it byte-for-byte against a
//! committed baseline in tests/golden/. On an intentional rendering change,
//! regenerate with `zig build update-golden` and review the diff.
//!
//! Lives at the repo root so @embedFile("tests/golden/…") and the src/test
//! fixtures both resolve within the module root.

const std = @import("std");
const golden = @import("golden");

fn checkGolden(comptime baseline: []const u8, fixture: []const u8, mode: golden.Mode) !void {
    const expected = @embedFile("tests/golden/" ++ baseline);
    const actual = try golden.renderFixture(std.testing.io, std.testing.allocator, fixture, mode);
    defer std.testing.allocator.free(actual);
    std.testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print(
            "\ngolden mismatch for {s} — if the change is intentional, run `zig build update-golden` and review the diff.\n",
            .{baseline},
        );
        return err;
    };
}

test "golden: test_policy (plain)" {
    try checkGolden("test_policy.typ", "src/test/test_policy.md", .plain);
}

test "golden: test_policy (redacted)" {
    try checkGolden("test_policy_redacted.typ", "src/test/test_policy.md", .redact);
}

test "golden: test_policy (draft)" {
    try checkGolden("test_policy_draft.typ", "src/test/test_policy.md", .draft);
}

test "golden: test_policy_render (plain)" {
    try checkGolden("test_policy_render.typ", "src/test/test_policy_render.md", .plain);
}

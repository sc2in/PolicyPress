const std = @import("std");
const testing = std.testing;
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;

// Import the relevant modules from your main file.
const main = @import("pandoc.zig"); // Adjust path as needed

const DummyProgress = struct {
    pub fn start(_: DummyProgress, _: []const u8, _: usize) DummyProgress {
        return DummyProgress{};
    }
    pub fn end(_: DummyProgress) void {}
    pub fn setEstimatedTotalItems(_: DummyProgress, _: usize) void {}
    pub fn completeOne(_: DummyProgress) void {}
};

test "replace_org replaces organization shortcode" {
    const allocator = testing.allocator;

    // Setup global config
    main.global_config.org = try allocator.dupe(u8, "AcmeCorp");
    defer allocator.free(main.global_config.org);

    var arr = Array(u8).init(allocator);
    defer arr.deinit();
    try arr.appendSlice("Welcome to {{ org() }}!");

    var dummy_progress = DummyProgress{};

    try main.replace_org(&arr, &dummy_progress);

    try testing.expectEqualStrings("Welcome to AcmeCorp!", arr.items);
}

test "replace_mermaid replaces mermaid shortcode with code block" {
    const allocator = testing.allocator;

    var arr = Array(u8).init(allocator);
    defer arr.deinit();
    try arr.appendSlice(
        \\Some text
        \\{% mermaid() %}
        \\graph TD;
        \\A-->B;
        \\{% end %}
        \\End text
    );

    var dummy_progress = DummyProgress{};

    try main.replace_mermaid(&arr, &dummy_progress);

    const expected =
        \\Some text
        \\~~~mermaid
        \\graph TD;
        \\A-->B;
        \\~~~
        \\End text
    ;
    try testing.expectEqualStrings(expected, arr.items);
}

test "create_global_args constructs correct arguments" {
    const allocator = testing.allocator;

    // Minimal config for test
    main.global_config.root = try allocator.dupe(u8, "root");
    main.global_config.org = try allocator.dupe(u8, "AcmeCorp");
    main.global_config.logo_path = try allocator.dupe(u8, "static/logo.png");
    main.global_config.color = try allocator.dupe(u8, "#123456");
    main.global_config.current_year = try allocator.dupe(u8, "2025");
    main.global_config.is_draft = false;
    main.global_config.redact = false;

    defer main.global_config.deinit(allocator);
    errdefer main.global_config.deinit(allocator);

    var args = Array([]u8).init(allocator);

    try main.create_global_args(allocator, &args);
    defer main.destroy_global_args(allocator, args);
    // Check that some expected arguments are present
    var found = false;
    for (args.items) |arg| {
        if (std.mem.startsWith(u8, arg, "--data-dir=")) found = true;
    }
    try testing.expect(found);
    found = false;
    for (args.items) |arg| {
        if (std.mem.eql(u8, arg, "footer-left=AcmeCorp \\textcopyright 2025")) found = true;
    }
    // std.debug.print("{s}\n", .{args.items});
    try testing.expect(found);
}

test "FrontMatter.filename generates expected filename" {
    const allocator = testing.allocator;

    main.global_config.build_dir = "build";
    var fm = main.FrontMatter{
        .title = try allocator.dupe(u8, "Policy"),
        .most_recent_version = try allocator.dupe(u8, "1.0"),
        .last_reviewed = try allocator.dupe(u8, "2025-06-10"),
    };
    defer fm.deinit(allocator);
    const fname = try fm.filename(allocator);
    defer allocator.free(fname);

    try testing.expectEqualStrings("build/Policy - v1.0.pdf", fname);
}

test "revisions_lt sorts revisions lexically" {
    // Simulate two YAML values
    const Yaml = @import("yaml").Yaml;
    const a = Yaml.Value{ .string = "2022-01-01" };
    const b = Yaml.Value{ .string = "2023-01-01" };
    try testing.expect(main.revisions_lt(.{}, a, b));
    try testing.expect(!main.revisions_lt(.{}, b, a));
}

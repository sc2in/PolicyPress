//! Filters for Tera templates
//! Built-in and custom filters for transforming template values

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const context = @import("context.zig");

/// Filter function type
pub const FilterFn = *const fn (allocator: Allocator, value: context.Value, args: []const context.Value) anyerror!context.Value;

/// Register all built-in filters
pub fn registerBuiltinFilters(filters: *std.StringHashMap(FilterFn)) void {
    // String filters
    filters.put("upper", upperFilter) catch {};
    filters.put("lower", lowerFilter) catch {};
    filters.put("capitalize", capitalizeFilter) catch {};
    filters.put("title", titleFilter) catch {};
    filters.put("trim", trimFilter) catch {};
    filters.put("length", lengthFilter) catch {};
    filters.put("wordcount", wordcountFilter) catch {};
    filters.put("replace", replaceFilter) catch {};
    filters.put("truncate", truncateFilter) catch {};
    filters.put("urlencode", urlencodeFilter) catch {};

    // Number filters
    filters.put("round", roundFilter) catch {};
    filters.put("abs", absFilter) catch {};
    filters.put("int", intFilter) catch {};
    filters.put("float", floatFilter) catch {};

    // Array filters
    filters.put("first", firstFilter) catch {};
    filters.put("last", lastFilter) catch {};
    filters.put("join", joinFilter) catch {};
    filters.put("reverse", reverseFilter) catch {};
    filters.put("sort", sortFilter) catch {};
    filters.put("unique", uniqueFilter) catch {};

    // Utility filters
    filters.put("default", defaultFilter) catch {};
    filters.put("escape", escapeFilter) catch {};
    filters.put("safe", safeFilter) catch {};
    filters.put("date", dateFilter) catch {};
    filters.put("json", jsonFilter) catch {};
}

// String filters

/// Convert string to uppercase
fn upperFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    const str_value = try value.toString(allocator);
    defer allocator.free(str_value);

    var result = try allocator.alloc(u8, str_value.len);
    for (str_value, 0..) |c, i| {
        result[i] = std.ascii.toUpper(c);
    }

    return context.Value{ .string = result };
}

/// Convert string to lowercase
fn lowerFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    const str_value = try value.toString(allocator);
    defer allocator.free(str_value);

    var result = try allocator.alloc(u8, str_value.len);
    for (str_value, 0..) |c, i| {
        result[i] = std.ascii.toLower(c);
    }

    return context.Value{ .string = result };
}

/// Capitalize first letter
fn capitalizeFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    const str_value = try value.toString(allocator);
    defer allocator.free(str_value);

    if (str_value.len == 0) {
        return context.Value{ .string = try allocator.dupe(u8, "") };
    }

    var result = try allocator.alloc(u8, str_value.len);
    result[0] = std.ascii.toUpper(str_value[0]);

    for (str_value[1..], 1..) |c, i| {
        result[i] = std.ascii.toLower(c);
    }

    return context.Value{ .string = result };
}

/// Title case (capitalize each word)
fn titleFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    const str_value = try value.toString(allocator);
    defer allocator.free(str_value);

    var result = try allocator.alloc(u8, str_value.len);
    var capitalize_next = true;

    for (str_value, 0..) |c, i| {
        if (std.ascii.isAlphabetic(c)) {
            result[i] = if (capitalize_next) std.ascii.toUpper(c) else std.ascii.toLower(c);
            capitalize_next = false;
        } else {
            result[i] = c;
            capitalize_next = true;
        }
    }

    return context.Value{ .string = result };
}

/// Trim whitespace
fn trimFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    const str_value = try value.toString(allocator);
    defer allocator.free(str_value);

    const trimmed = std.mem.trim(u8, str_value, " \t\n\r");
    return context.Value{ .string = try allocator.dupe(u8, trimmed) };
}

/// Get length of string or array
fn lengthFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    switch (value) {
        .string => |s| return context.Value{ .number = @floatFromInt(s.len) },
        .array => |arr| return context.Value{ .number = @floatFromInt(arr.items.len) },
        else => {
            const str_value = try value.toString(allocator);
            defer allocator.free(str_value);
            return context.Value{ .number = @floatFromInt(str_value.len) };
        },
    }
}

/// Count words in string
fn wordcountFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    const str_value = try value.toString(allocator);
    defer allocator.free(str_value);

    var word_count: usize = 0;
    var in_word = false;

    for (str_value) |c| {
        if (std.ascii.isAlphabetic(c)) {
            if (!in_word) {
                word_count += 1;
                in_word = true;
            }
        } else {
            in_word = false;
        }
    }

    return context.Value{ .number = @floatFromInt(word_count) };
}

/// Replace occurrences of a substring
fn replaceFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    if (args.len < 2) return try value.clone(allocator);

    const str_value = try value.toString(allocator);
    defer allocator.free(str_value);

    const from_str = try args[0].toString(allocator);
    defer allocator.free(from_str);

    const to_str = try args[1].toString(allocator);
    defer allocator.free(to_str);

    const result = try std.mem.replaceOwned(u8, allocator, str_value, from_str, to_str);
    return context.Value{ .string = result };
}

/// Truncate string to specified length
fn truncateFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    const str_value = try value.toString(allocator);
    defer allocator.free(str_value);

    const max_len = if (args.len > 0) blk: {
        if (args[0].toNumber()) |n| {
            break :blk @as(usize, @intFromFloat(n));
        } else {
            break :blk str_value.len;
        }
    } else str_value.len;

    if (str_value.len <= max_len) {
        return context.Value{ .string = try allocator.dupe(u8, str_value) };
    }

    const suffix = if (args.len > 1) blk: {
        const suffix_str = try args[1].toString(allocator);
        defer allocator.free(suffix_str);
        break :blk try allocator.dupe(u8, suffix_str);
    } else try allocator.dupe(u8, "...");
    defer allocator.free(suffix);

    const truncate_at = if (max_len > suffix.len) max_len - suffix.len else 0;
    const result = try std.fmt.allocPrint(allocator, "{s}{s}", .{ str_value[0..truncate_at], suffix });

    return context.Value{ .string = result };
}

/// URL encode string
fn urlencodeFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    const str_value = try value.toString(allocator);
    defer allocator.free(str_value);

    var result = ArrayList(u8){};
    defer result.deinit(allocator);

    for (str_value) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
            try result.append(allocator, c);
        } else {
            try result.appendSlice(allocator, try std.fmt.allocPrint(allocator, "%{X:0>2}", .{c}));
        }
    }

    return context.Value{ .string = try result.toOwnedSlice(allocator) };
}

// Number filters

/// Round number to specified decimal places
fn roundFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    const num = value.toNumber() orelse return try value.clone(allocator);

    const precision = if (args.len > 0) blk: {
        if (args[0].toNumber()) |p| {
            break :blk @as(i32, @intFromFloat(p));
        } else {
            break :blk @as(i32, 0);
        }
    } else 0;

    const multiplier = std.math.pow(f64, 10, @floatFromInt(precision));
    const rounded = @round(num * multiplier) / multiplier;

    return context.Value{ .number = rounded };
}

/// Absolute value
fn absFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    const num = value.toNumber() orelse return try value.clone(allocator);
    return context.Value{ .number = @abs(num) };
}

/// Convert to integer
fn intFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = allocator;
    _ = args;

    const num = value.toNumber() orelse return context.Value{ .number = 0 };
    return context.Value{ .number = @floor(num) };
}

/// Convert to float
fn floatFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;
    _ = allocator;

    switch (value) {
        .number => |n| return context.Value{ .number = n },
        .string => |s| {
            if (std.fmt.parseFloat(f64, s)) |n| {
                return context.Value{ .number = n };
            } else |_| {
                return context.Value{ .number = 0 };
            }
        },
        else => return context.Value{ .number = 0 },
    }
}

// Array filters

/// Get first element of array
fn firstFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    switch (value) {
        .array => |arr| {
            if (arr.items.len > 0) {
                return try arr.items[0].clone(allocator);
            }
        },
        .string => |s| {
            if (s.len > 0) {
                return context.Value{ .string = try allocator.dupe(u8, s[0..1]) };
            }
        },
        else => {},
    }

    return context.Value{ .null_value = {} };
}

/// Get last element of array
fn lastFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    switch (value) {
        .array => |arr| {
            if (arr.items.len > 0) {
                return try arr.items[arr.items.len - 1].clone(allocator);
            }
        },
        .string => |s| {
            if (s.len > 0) {
                return context.Value{ .string = try allocator.dupe(u8, s[s.len - 1 ..]) };
            }
        },
        else => {},
    }

    return context.Value{ .null_value = {} };
}

/// Join array elements with separator
fn joinFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    const separator = if (args.len > 0) blk: {
        const sep_str = try args[0].toString(allocator);
        defer allocator.free(sep_str);
        break :blk try allocator.dupe(u8, sep_str);
    } else try allocator.dupe(u8, "");
    defer allocator.free(separator);

    switch (value) {
        .array => |arr| {
            var result = ArrayList(u8){};
            defer result.deinit(allocator);

            for (arr.items, 0..) |item, i| {
                if (i > 0) try result.appendSlice(allocator, separator);
                const item_str = try item.toString(allocator);
                defer allocator.free(item_str);
                try result.appendSlice(allocator, item_str);
            }

            return context.Value{ .string = try result.toOwnedSlice(allocator) };
        },
        else => return try value.clone(allocator),
    }
}

/// Reverse array or string
fn reverseFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    switch (value) {
        .array => |arr| {
            var new_array = ArrayList(context.Value){};

            var i = arr.items.len;
            while (i > 0) {
                i -= 1;
                try new_array.append(allocator, try arr.items[i].clone(allocator));
            }

            return context.Value{ .array = new_array };
        },
        .string => |s| {
            var result = try allocator.alloc(u8, s.len);

            for (s, 0..) |c, i| {
                result[s.len - 1 - i] = c;
            }

            return context.Value{ .string = result };
        },
        else => return try value.clone(allocator),
    }
}

/// Sort array
fn sortFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    switch (value) {
        .array => |arr| {
            var new_array = ArrayList(context.Value){};

            // Simple sort for numbers and strings
            for (arr.items) |item| {
                try new_array.append(allocator, try item.clone(allocator));
            }

            // Basic bubble sort for simplicity
            for (0..new_array.items.len) |i| {
                for (i + 1..new_array.items.len) |j| {
                    const should_swap = blk: {
                        const a = new_array.items[i];
                        const b = new_array.items[j];

                        switch (a) {
                            .number => |an| {
                                switch (b) {
                                    .number => |bn| break :blk an > bn,
                                    else => break :blk false,
                                }
                            },
                            .string => |as| {
                                switch (b) {
                                    .string => |bs| break :blk std.mem.order(u8, as, bs) == .gt,
                                    else => break :blk false,
                                }
                            },
                            else => break :blk false,
                        }
                    };

                    if (should_swap) {
                        const temp = new_array.items[i];
                        new_array.items[i] = new_array.items[j];
                        new_array.items[j] = temp;
                    }
                }
            }

            return context.Value{ .array = new_array };
        },
        else => return try value.clone(allocator),
    }
}

/// Get unique elements from array
fn uniqueFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    switch (value) {
        .array => |arr| {
            var new_array = ArrayList(context.Value){};

            for (arr.items) |item| {
                var is_duplicate = false;
                for (new_array.items) |existing| {
                    if (item.equals(existing)) {
                        is_duplicate = true;
                        break;
                    }
                }

                if (!is_duplicate) {
                    try new_array.append(allocator, try item.clone(allocator));
                }
            }

            return context.Value{ .array = new_array };
        },
        else => return try value.clone(allocator),
    }
}

// Utility filters

/// Provide default value if original is falsy
fn defaultFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    if (value.isTruthy()) {
        return try value.clone(allocator);
    }

    if (args.len > 0) {
        return try args[0].clone(allocator);
    }

    return context.Value{ .string = try allocator.dupe(u8, "") };
}

/// Escape HTML characters
fn escapeFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    const str_value = try value.toString(allocator);
    defer allocator.free(str_value);

    var result = ArrayList(u8){};
    defer result.deinit(allocator);

    for (str_value) |c| {
        switch (c) {
            '&' => try result.appendSlice(allocator, "&amp;"),
            '<' => try result.appendSlice(allocator, "&lt;"),
            '>' => try result.appendSlice(allocator, "&gt;"),
            '"' => try result.appendSlice(allocator, "&quot;"),
            '\'' => try result.appendSlice(allocator, "&#x27;"),
            else => try result.append(allocator, c),
        }
    }

    return context.Value{ .string = try result.toOwnedSlice(allocator) };
}

/// Mark value as safe (no-op in this implementation)
fn safeFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;
    return try value.clone(allocator);
}

/// Format date (basic implementation)
fn dateFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    // Basic date formatting - in a real implementation this would parse and format dates
    const str_value = try value.toString(allocator);
    return context.Value{ .string = str_value };
}

/// Convert value to JSON
fn jsonFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    _ = args;

    switch (value) {
        .string => |s| {
            const json_str = try std.fmt.allocPrint(allocator, "{s}", .{s});
            return context.Value{ .string = json_str };
        },
        .number => |n| {
            const json_str = try std.fmt.allocPrint(allocator, "{d}", .{n});
            return context.Value{ .string = json_str };
        },
        .boolean => |b| {
            const json_str = try allocator.dupe(u8, if (b) "true" else "false");
            return context.Value{ .string = json_str };
        },
        .null_value => {
            return context.Value{ .string = try allocator.dupe(u8, "null") };
        },
        else => {
            const str_value = try value.toString(allocator);
            return context.Value{ .string = str_value };
        },
    }
}

// Tests
const expect = std.testing.expect;

test "upper filter" {
    const allocator = std.testing.allocator;

    const value = context.Value{ .string = "hello world" };
    var result = try upperFilter(allocator, value, &[_]context.Value{});
    defer result.deinit(allocator);
    errdefer result.deinit(allocator);

    try expect(std.mem.eql(u8, result.string, "HELLO WORLD"));
}

test "length filter" {
    const allocator = std.testing.allocator;

    const value = context.Value{ .string = "hello" };
    const result = try lengthFilter(allocator, value, &[_]context.Value{});

    try expect(result.number == 5);
}

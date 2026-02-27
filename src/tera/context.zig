//! Copyright © 2025 [Star City Security Consulting, LLC (SC2)](https://sc2.in)
//! SPDX-License-Identifier: AGPL-3.0-or-later
//! Context module for Tera templates
//! Manages template variables and data structures

const std = @import("std");
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Allocator = std.mem.Allocator;

/// Value types that can be stored in the context
pub const Value = union(enum) {
    string: []const u8,
    number: f64,
    boolean: bool,
    array: ArrayList(Value),
    object: Context,
    null_value: void,

    const Self = @This();

    /// Convert value to string representation
    pub fn toString(self: Self, allocator: Allocator) ![]u8 {
        switch (self) {
            .string => |s| return allocator.dupe(u8, s),
            .number => |n| {
                if (n == @floor(n)) {
                    return std.fmt.allocPrint(allocator, "{d}", .{@as(i64, @intFromFloat(n))});
                } else {
                    return std.fmt.allocPrint(allocator, "{d}", .{n});
                }
            },
            .boolean => |b| return allocator.dupe(u8, if (b) "true" else "false"),
            .array => |arr| {
                var result = ArrayList(u8){};
                defer result.deinit(allocator);

                try result.append(allocator, '[');
                for (arr.items, 0..) |item, i| {
                    if (i > 0) try result.appendSlice(allocator, ", ");
                    const item_str = try item.toString(allocator);
                    defer allocator.free(item_str);
                    try result.appendSlice(allocator, item_str);
                }
                try result.append(allocator, ']');

                return result.toOwnedSlice(allocator);
            },
            .object => |obj| {
                var result = ArrayList(u8){};
                defer result.deinit(allocator);
                try result.append(allocator, '{');
                var it = obj.data.iterator();
                var first = true;
                while (it.next()) |entry| {
                    if (!first) try result.appendSlice(allocator, ", ");
                    first = false;
                    try result.appendSlice(allocator, entry.key_ptr.*);
                    try result.appendSlice(allocator, ": ");
                    const val_str = try entry.value_ptr.toString(allocator);
                    defer allocator.free(val_str);
                    try result.appendSlice(allocator, val_str);
                }
                try result.append(allocator, '}');
                return try result.toOwnedSlice(allocator);
            },
            .null_value => return allocator.dupe(u8, ""),
        }
    }

    /// Check if value is truthy
    pub fn isTruthy(self: Self) bool {
        switch (self) {
            .string => |s| return s.len > 0,
            .number => |n| return n != 0,
            .boolean => |b| return b,
            .array => |arr| return arr.items.len > 0,
            .object => return true,
            .null_value => return false,
        }
    }

    /// Get numeric value
    pub fn toNumber(self: Self) ?f64 {
        switch (self) {
            .number => |n| return n,
            .string => |s| return std.fmt.parseFloat(f64, s) catch null,
            .boolean => |b| return if (b) 1.0 else 0.0,
            else => return null,
        }
    }

    /// Compare values for equality
    pub fn equals(self: Self, other: Self) bool {
        switch (self) {
            .string => |s| {
                switch (other) {
                    .string => |os| return std.mem.eql(u8, s, os),
                    else => return false,
                }
            },
            .number => |n| {
                switch (other) {
                    .number => |on| return n == on,
                    else => return false,
                }
            },
            .boolean => |b| {
                switch (other) {
                    .boolean => |ob| return b == ob,
                    else => return false,
                }
            },
            .null_value => {
                switch (other) {
                    .null_value => return true,
                    else => return false,
                }
            },
            else => return false,
        }
    }

    /// Deep clone a value
    pub fn clone(self: Self, allocator: Allocator) anyerror!Self {
        switch (self) {
            .string => |s| return Self{ .string = try allocator.dupe(u8, s) },
            .number => |n| return Self{ .number = n },
            .boolean => |b| return Self{ .boolean = b },
            .array => |arr| {
                var new_array = ArrayList(Value){};
                for (arr.items) |item| {
                    try new_array.append(allocator, try item.clone(allocator));
                }
                return Self{ .array = new_array };
            },
            .object => |obj| {
                var new_obj = Context.init(allocator);
                var iter = obj.data.iterator();
                while (iter.next()) |entry| {
                    const val = try entry.value_ptr.clone(allocator);
                    try new_obj.set(entry.key_ptr.*, val);
                }
                return Self{ .object = new_obj };
            },
            .null_value => return Self{ .null_value = {} },
        }
    }

    /// Free memory used by value
    pub fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| {
                // _ = s;
                allocator.free(s);
            },
            .array => |*arr| {
                for (arr.items) |*item| {
                    item.deinit(allocator);
                }
                arr.deinit(allocator);
            },
            .object => |*obj| obj.deinit(),
            else => {},
        }
    }
};

/// Context for template rendering
pub const Context = struct {
    allocator: Allocator,
    data: std.StringHashMap(Value),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .data = std.StringHashMap(Value).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var value = entry.value_ptr.*;
            value.deinit(self.allocator);
        }
        self.data.deinit();
    }

    /// Set a variable in the context
    pub fn set(self: *Self, key: []const u8, value: Value) !void {
        const owned_key = try self.allocator.dupe(u8, key);
        const cloned_value = try value.clone(self.allocator);
        try self.data.put(owned_key, cloned_value);
    }

    /// Get a variable from the context
    pub fn get(self: *Self, key: []const u8) ?Value {
        return self.data.get(key);
    }

    /// Get a nested value using dot notation (e.g., "user.name")
    pub fn getPath(self: *Self, path: []const u8) ?Value {
        var parts = std.mem.splitScalar(u8, path, '.');
        var current_value = self.get(parts.first()) orelse return null;

        while (parts.next()) |part| {
            switch (current_value) {
                .object => |obj| {
                    current_value = obj.data.get(part) orelse return null;
                },
                else => return null,
            }
        }

        return current_value;
    }

    /// Check if a variable exists
    pub fn has(self: *Self, key: []const u8) bool {
        return self.data.contains(key);
    }

    /// Remove a variable
    pub fn remove(self: *Self, key: []const u8) void {
        if (self.data.fetchRemove(key)) |entry| {
            self.allocator.free(entry.key);
            var value = entry.value;
            value.deinit(self.allocator);
        }
    }

    /// Create a new context with additional variables
    pub fn extend(self: *Self, other: *const Self) !Self {
        var new_context = Self.init(self.allocator);

        // Copy current context
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            try new_context.set(entry.key_ptr.*, entry.value_ptr.*);
        }

        // Add variables from other context
        iter = other.data.iterator();
        while (iter.next()) |entry| {
            try new_context.set(entry.key_ptr.*, entry.value_ptr.*);
        }

        return new_context;
    }

    /// Create context from JSON string
    pub fn fromJson(allocator: Allocator, json_str: []const u8) !Self {
        var context = Self.init(allocator);

        var parsed = std.json.parseFromSlice(std.json.Value, allocator, json_str, .{}) catch return context;
        defer parsed.deinit();

        try parseJsonValue(&context, parsed.value, "");

        return context;
    }
    /// Create context from JSON Value
    pub fn fromJsonValue(allocator: Allocator, json: std.json.Value) !Self {
        var context = Self.init(allocator);

        try parseJsonValue(&context, json, "");

        return context;
    }

    /// Convert context to JSON string
    pub fn toJson(self: *Self, allocator: Allocator) ![]u8 {
        var result = ArrayList(u8).init(allocator);
        defer result.deinit();

        try result.append('{');

        var iter = self.data.iterator();
        var first = true;
        while (iter.next()) |entry| {
            if (!first) try result.appendSlice(", ");
            first = false;

            try result.append('"');
            try result.appendSlice(entry.key_ptr.*);
            try result.appendSlice(": ");

            const value_json = try valueToJson(entry.value_ptr.*, allocator);
            defer allocator.free(value_json);
            try result.appendSlice(value_json);
        }

        try result.append('}');
        return result.toOwnedSlice();
    }

    /// Create a scoped context (for loops, blocks, etc.)
    pub fn createScope(self: *Self) Self {
        return Self.init(self.allocator);
    }

    /// Debug print context contents
    pub fn debug(self: *Self) void {
        std.debug.print("Context contents:\n");
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            const value_str = entry.value_ptr.toString(self.allocator) catch "Error";
            defer self.allocator.free(value_str);
            std.debug.print("  {s} = {s}\n", .{ entry.key_ptr.*, value_str });
        }
    }
};

/// Helper function to parse JSON value into context
fn parseJsonValue(context: *Context, json_value: std.json.Value, prefix: []const u8) !void {
    switch (json_value) {
        .null => {
            if (prefix.len > 0) {
                try context.set(prefix, Value{ .null_value = {} });
            }
        },
        .bool => |b| {
            try context.set(prefix, Value{ .boolean = b });
        },
        .integer => |i| {
            try context.set(prefix, Value{ .number = @floatFromInt(i) });
        },
        .float => |f| {
            try context.set(prefix, Value{ .number = f });
        },
        .string => |s| {
            try context.set(prefix, Value{ .string = s });
        },
        .array => |arr| {
            var array_list = ArrayList(Value){};

            for (arr.items) |item| {
                const value = try jsonValueToValue(item, context.allocator);
                try array_list.append(context.allocator, value);
            }

            try context.set(prefix, Value{ .array = array_list });
        },
        .object => |obj| {
            if (prefix.len == 0) {
                // Root object - add each key to context
                var iter = obj.iterator();
                while (iter.next()) |entry| {
                    try parseJsonValue(context, entry.value_ptr.*, entry.key_ptr.*);
                }
            } else {
                // Nested object - create sub-context
                var sub_context = Context.init(context.allocator);
                var iter = obj.iterator();
                while (iter.next()) |entry| {
                    try parseJsonValue(&sub_context, entry.value_ptr.*, entry.key_ptr.*);
                }
                try context.set(prefix, Value{ .object = sub_context });
            }
        },
        .number_string => |num| {
            try context.set(prefix, Value{
                .number = try std.fmt.parseFloat(f64, num),
            });
        },
    }
}

/// Helper function to convert JSON value to Context Value
fn jsonValueToValue(json_value: std.json.Value, allocator: Allocator) !Value {
    switch (json_value) {
        .null => return Value{ .null_value = {} },
        .bool => |b| return Value{ .boolean = b },
        .integer => |i| return Value{ .number = @floatFromInt(i) },
        .float => |f| return Value{ .number = f },
        .string => |s| return Value{ .string = try allocator.dupe(u8, s) },
        .array => |arr| {
            var array_list = ArrayList(Value){};
            for (arr.items) |item| {
                try array_list.append(allocator, try jsonValueToValue(item, allocator));
            }
            return Value{ .array = array_list };
        },
        .object => |obj| {
            var context = Context.init(allocator);
            var iter = obj.iterator();
            while (iter.next()) |entry| {
                const value = try jsonValueToValue(entry.value_ptr.*, allocator);
                try context.set(entry.key_ptr.*, value);
            }
            return Value{ .object = context };
        },
        .number_string => |n| return Value{
            .number = try std.fmt.parseFloat(f64, n),
        },
    }
}

/// Helper function to convert Value to JSON string
fn valueToJson(value: Value, allocator: Allocator) ![]u8 {
    switch (value) {
        .null_value => return allocator.dupe(u8, "null"),
        .boolean => |b| return allocator.dupe(u8, if (b) "true" else "false"),
        .number => |n| {
            if (n == @floor(n)) {
                return std.fmt.allocPrint(allocator, "{d}", .{@as(i64, @intFromFloat(n))});
            } else {
                return std.fmt.allocPrint(allocator, "{d}", .{n});
            }
        },
        .string => |s| return std.fmt.allocPrint(allocator, "{s}", .{s}),
        .array => |arr| {
            var result = ArrayList(u8).init(allocator);
            defer result.deinit();

            try result.append('[');
            for (arr.items, 0..) |item, i| {
                if (i > 0) try result.appendSlice(", ");
                const item_json = try valueToJson(item, allocator);
                defer allocator.free(item_json);
                try result.appendSlice(item_json);
            }
            try result.append(']');

            return result.toOwnedSlice();
        },
        .object => |obj| {
            return obj.toJson(allocator);
        },
    }
}

// Tests
const expect = std.testing.expect;

test "context basic operations" {
    const allocator = std.testing.allocator;

    var ctx = Context.init(allocator);
    defer ctx.deinit();

    try ctx.set("name", Value{ .string = "test" });
    try ctx.set("count", Value{ .number = 42 });
    try ctx.set("active", Value{ .boolean = true });

    const name = ctx.get("name").?;
    try expect(std.mem.eql(u8, name.string, "test"));

    const count = ctx.get("count").?;
    try expect(count.number == 42);

    const active = ctx.get("active").?;
    try expect(active.boolean == true);
}

test "value to string conversion" {
    const allocator = std.testing.allocator;

    const str_val = Value{ .string = "hello" };
    const str_result = try str_val.toString(allocator);
    defer allocator.free(str_result);
    try expect(std.mem.eql(u8, str_result, "hello"));

    const num_val = Value{ .number = 42.5 };
    const num_result = try num_val.toString(allocator);
    defer allocator.free(num_result);
    try expect(std.mem.startsWith(u8, num_result, "42.5"));

    const bool_val = Value{ .boolean = true };
    const bool_result = try bool_val.toString(allocator);
    defer allocator.free(bool_result);
    try expect(std.mem.eql(u8, bool_result, "true"));
}

//! Tera Template Engine Interpreter for Zig 0.14.1
//! A complete implementation of Tera template engine using only Zig standard library
//!
//! Features supported:
//! - Variable interpolation: {{ variable }}
//! - Comments: {# comment #}
//! - Control structures: {% if %}, {% for %}, {% block %}
//! - Template inheritance: {% extends %}, {% block %}
//! - Filters: {{ variable | filter }}
//! - Basic expressions and operators
//! - Context management with JSON-like data structures

const std = @import("std");
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Array = ArrayList;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;

// Re-export modules for easier access
pub const lexer = @import("lexer.zig");
pub const parser = @import("parser.zig");
pub const context = @import("context.zig");
pub const renderer = @import("renderer.zig");
pub const filters = @import("filters.zig");

pub const TeraError = error{
    ParseError,
    RenderError,
    TemplateNotFound,
    VariableNotFound,
    FilterNotFound,
    SyntaxError,
    OutOfMemory,
    InvalidTemplate,
    CircularInheritance,
};

/// Main Tera engine struct
pub const Tera = struct {
    allocator: Allocator,
    templates: HashMap([]const u8, parser.Template, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    filters: HashMap([]const u8, filters.FilterFn, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    names: Array([]u8),
    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        var tera = Self{
            .allocator = allocator,
            .templates = HashMap([]const u8, parser.Template, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .filters = HashMap([]const u8, filters.FilterFn, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .names = Array([]u8).init(allocator),
        };

        // Register built-in filters
        filters.registerBuiltinFilters(&tera.filters);

        return tera;
    }

    pub fn deinit(self: *Self) void {
        var template_iterator = self.templates.iterator();
        while (template_iterator.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.templates.deinit();
        self.filters.deinit();
        for (self.names.items) |n|
            self.allocator.free(n);
        self.names.deinit();
    }

    /// Add a template from string content
    pub fn addTemplate(self: *Self, name: []const u8, content: []const u8) TeraError!void {
        var lexer_instance = lexer.Lexer.init(self.allocator, content);
        defer lexer_instance.deinit();

        const tokens = lexer_instance.tokenize() catch return TeraError.ParseError;
        defer self.allocator.free(tokens);

        var parser_instance = parser.Parser.init(self.allocator, tokens);
        defer parser_instance.deinit();

        const template = parser_instance.parse() catch return TeraError.ParseError;

        const owned_name = self.allocator.dupe(u8, name) catch return TeraError.OutOfMemory;
        self.names.append(owned_name) catch return TeraError.OutOfMemory;
        self.templates.put(owned_name, template) catch return TeraError.OutOfMemory;
    }

    /// Render a template with given context
    pub fn render(self: *Self, template_name: []const u8, ctx: context.Context) TeraError![]u8 {
        const template = self.templates.get(template_name) orelse return TeraError.TemplateNotFound;

        var renderer_instance = renderer.Renderer.init(self.allocator, self, ctx);
        defer renderer_instance.deinit();

        return renderer_instance.render(template) catch TeraError.RenderError;
    }

    /// Get template by name (used internally)
    pub fn getTemplate(self: *Self, name: []const u8) ?parser.Template {
        return self.templates.get(name);
    }

    /// Register a custom filter
    pub fn registerFilter(self: *Self, name: []const u8, filter_fn: filters.FilterFn) TeraError!void {
        const owned_name = self.allocator.dupe(u8, name) catch return TeraError.OutOfMemory;
        self.names.append(owned_name) catch return TeraError.OutOfMemory;

        self.filters.put(owned_name, filter_fn) catch return TeraError.OutOfMemory;
    }

    /// Get filter by name
    pub fn getFilter(self: *Self, name: []const u8) ?filters.FilterFn {
        return self.filters.get(name);
    }
};

// Example usage and tests
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tera = Tera.init(allocator);
    defer tera.deinit();

    // Add a simple template
    try tera.addTemplate("hello", "Hello, {{ name }}! You have {{ count }} messages.");

    // Create context
    var ctx = context.Context.init(allocator);
    defer ctx.deinit();

    try ctx.set("name", context.Value{ .string = "World" });
    try ctx.set("count", context.Value{ .number = 42 });

    // Render template
    const result = try tera.render("hello", ctx);
    defer allocator.free(result);

    std.debug.print("Rendered: {s}\n", .{result});

    // More complex example with loops and conditions
    const complex_template =
        \\<h1>{{ title }}</h1>
        \\{% if users %}
        \\<ul>
        \\{% for user in users %}
        \\  <li>{{ user.name }} ({{ user.email }})</li>
        \\{% endfor %}
        \\</ul>
        \\{% else %}
        \\<p>No users found.</p>
        \\{% endif %}
    ;

    try tera.addTemplate("users", complex_template);

    var ctx2 = context.Context.init(allocator);
    defer ctx2.deinit();

    try ctx2.set("title", context.Value{ .string = "User List" });

    // Create array of users
    var users = ArrayList(context.Value).init(allocator);
    defer users.deinit();

    var user1 = context.Context.init(allocator);
    defer user1.deinit();
    try user1.set("name", context.Value{ .string = "John Doe" });
    try user1.set("email", context.Value{ .string = "john@example.com" });

    var user2 = context.Context.init(allocator);
    defer user2.deinit();
    try user2.set("name", context.Value{ .string = "Jane Smith" });
    try user2.set("email", context.Value{ .string = "jane@example.com" });

    try users.append(context.Value{ .object = user1 });
    try users.append(context.Value{ .object = user2 });

    try ctx2.set("users", context.Value{ .array = users });

    const result2 = try tera.render("users", ctx2);
    defer allocator.free(result2);

    std.debug.print("Complex template result:\n{s}\n", .{result2});
}

test "basic template rendering" {
    const allocator = std.testing.allocator;

    var tera = Tera.init(allocator);
    defer tera.deinit();

    try tera.addTemplate("test", "Hello, {{ name }}!");

    var ctx = context.Context.init(allocator);
    defer ctx.deinit();

    try ctx.set("name", context.Value{ .string = "Zig" });

    const result = try tera.render("test", ctx);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello, Zig!", result);
}

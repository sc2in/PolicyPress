//! Renderer for Tera templates
//! Evaluates AST nodes and produces final output

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
const context = @import("context.zig");

/// Forward declaration for Tera type
const Tera = @import("tera.zig").Tera;

/// Renderer for evaluating templates
pub const Renderer = struct {
    allocator: Allocator,
    tera: *Tera,
    context: context.Context,
    output: ArrayList(u8),

    const Self = @This();

    pub fn init(allocator: Allocator, tera: *Tera, ctx: context.Context) Self {
        return Self{
            .allocator = allocator,
            .tera = tera,
            .context = ctx,
            .output = ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit();
    }

    /// Render a template and return the output
    pub fn render(self: *Self, template: parser.Template) ![]u8 {
        // Handle template inheritance
        if (template.parent) |parent_name| {
            return try self.renderWithInheritance(template, parent_name);
        }

        try self.renderNode(template.root);
        return self.output.toOwnedSlice();
    }

    /// Render template with inheritance
    fn renderWithInheritance(self: *Self, child_template: parser.Template, parent_name: []const u8) ![]u8 {
        const parent_template = self.tera.getTemplate(parent_name) orelse {
            // Fallback to child template if parent not found
            try self.renderNode(child_template.root);
            return self.output.toOwnedSlice();
        };

        // Render parent template, replacing blocks with child blocks
        try self.renderNodeWithBlocks(parent_template.root, child_template.blocks);
        return self.output.toOwnedSlice();
    }

    /// Render a node
    fn renderNode(self: *Self, node: *parser.Node) anyerror!void {
        switch (node.type) {
            .template => {
                for (node.children.items) |child| {
                    try self.renderNode(child);
                }
            },
            .text => {
                try self.output.appendSlice(node.content);
            },
            .variable => {
                try self.renderVariable(node);
            },
            .if_statement => {
                try self.renderIf(node);
            },
            .for_loop => {
                try self.renderFor(node);
            },
            .block => {
                try self.renderBlock(node);
            },
            .comment => {
                // Comments are ignored in output
            },
            .include => {
                try self.renderInclude(node);
            },
            .set => {
                try self.renderSet(node);
            },
            else => {
                // Handle other node types or ignore
            },
        }
    }

    /// Render node with block replacements
    fn renderNodeWithBlocks(self: *Self, node: *parser.Node, blocks: std.StringHashMap(*parser.Node)) !void {
        switch (node.type) {
            .template => {
                for (node.children.items) |child| {
                    try self.renderNodeWithBlocks(child, blocks);
                }
            },
            .block => {
                if (node.getAttribute("name")) |block_name| {
                    if (blocks.get(block_name)) |replacement_block| {
                        // Render child block content
                        for (replacement_block.children.items) |child| {
                            try self.renderNode(child);
                        }
                    } else {
                        // Render original block content
                        for (node.children.items) |child| {
                            try self.renderNode(child);
                        }
                    }
                } else {
                    for (node.children.items) |child| {
                        try self.renderNode(child);
                    }
                }
            },
            else => {
                try self.renderNode(node);
            },
        }
    }

    /// Render variable with filters
    fn renderVariable(self: *Self, node: *parser.Node) !void {
        if (node.children.items.len == 0) return;

        // Evaluate the main expression
        var value = try self.evaluateExpression(node.children.items[0]);
        defer value.deinit(self.allocator);

        // Apply filters
        for (node.children.items[1..]) |filter_node| {
            if (filter_node.type == .filter) {
                value = try self.applyFilter(value, filter_node);
            }
        }

        // Convert to string and output
        const str_value = try value.toString(self.allocator);
        defer self.allocator.free(str_value);
        try self.output.appendSlice(str_value);
    }

    /// Render if statement
    fn renderIf(self: *Self, node: *parser.Node) !void {
        if (node.children.items.len < 2) return;

        var i: usize = 0;
        while (i < node.children.items.len) {
            // Evaluate condition
            var condition = try self.evaluateExpression(node.children.items[i]);
            defer condition.deinit(self.allocator);

            if (condition.isTruthy()) {
                // Render the corresponding body
                if (i + 1 < node.children.items.len) {
                    try self.renderNode(node.children.items[i + 1]);
                }
                return;
            }

            i += 2; // Skip condition and body
        }
    }

    /// Render for loop
    fn renderFor(self: *Self, node: *parser.Node) !void {
        if (node.children.items.len < 2) return;

        const var_name = node.getAttribute("var") orelse "item";

        // Evaluate iterable
        var iterable = try self.evaluateExpression(node.children.items[0]);
        defer iterable.deinit(self.allocator);

        switch (iterable) {
            .array => |arr| {
                for (arr.items, 0..) |item, index| {
                    // Create loop context
                    var loop_context = try self.context.extend(&self.context);
                    defer loop_context.deinit();

                    try loop_context.set(var_name, item);
                    try loop_context.set("loop", context.Value{ .object = try self.createLoopContext(index, arr.items.len) });

                    // Temporarily replace context
                    const old_context = self.context;
                    self.context = loop_context;
                    defer self.context = old_context;

                    // Render loop body
                    try self.renderNode(node.children.items[1]);
                }
            },
            .object => |obj| {
                var iter = obj.data.iterator();
                var index: usize = 0;
                const total = obj.data.count();

                while (iter.next()) |entry| {
                    // Create loop context
                    var loop_context = try self.context.extend(&self.context);
                    defer loop_context.deinit();

                    try loop_context.set(var_name, entry.value_ptr.*);
                    try loop_context.set("loop", context.Value{ .object = try self.createLoopContext(index, total) });

                    // Temporarily replace context
                    const old_context = self.context;
                    self.context = loop_context;
                    defer self.context = old_context;

                    // Render loop body
                    try self.renderNode(node.children.items[1]);

                    index += 1;
                }
            },
            else => {
                // Not iterable, skip
            },
        }
    }

    /// Render block
    fn renderBlock(self: *Self, node: *parser.Node) !void {
        for (node.children.items) |child| {
            try self.renderNode(child);
        }
    }

    /// Render include
    fn renderInclude(self: *Self, node: *parser.Node) !void {
        if (node.getAttribute("template")) |template_name| {
            if (self.tera.getTemplate(template_name)) |included_template| {
                var included_renderer = Renderer.init(self.allocator, self.tera, self.context);
                defer included_renderer.deinit();

                const included_output = try included_renderer.render(included_template);
                defer self.allocator.free(included_output);

                try self.output.appendSlice(included_output);
            }
        }
    }

    /// Render set statement
    fn renderSet(self: *Self, node: *parser.Node) !void {
        if (node.getAttribute("var")) |var_name| {
            if (node.children.items.len > 0) {
                const value = try self.evaluateExpression(node.children.items[0]);
                try self.context.set(var_name, value);
            }
        }
    }

    /// Evaluate an expression
    fn evaluateExpression(self: *Self, node: *parser.Node) anyerror!context.Value {
        switch (node.type) {
            .identifier => {
                // Look up variable in context
                if (self.context.get(node.content)) |value| {
                    return try value.clone(self.allocator);
                }

                // Handle dot notation for nested access
                if (std.mem.indexOf(u8, node.content, ".")) |_| {
                    if (self.context.getPath(node.content)) |value| {
                        return try value.clone(self.allocator);
                    }
                }

                // Handle member access from child nodes
                if (node.children.items.len > 0) {
                    var current_value = self.context.get(node.content) orelse return context.Value{ .null_value = {} };

                    for (node.children.items) |child| {
                        switch (current_value) {
                            .object => |obj| {
                                current_value = obj.data.get(child.content) orelse return context.Value{ .null_value = {} };
                            },
                            else => return context.Value{ .null_value = {} },
                        }
                    }

                    return try current_value.clone(self.allocator);
                }

                return context.Value{ .null_value = {} };
            },
            .literal => {
                return try self.parseLiteral(node.content);
            },
            .expression => {
                return try self.evaluateOperatorExpression(node);
            },
            else => {
                return context.Value{ .null_value = {} };
            },
        }
    }

    /// Parse literal value
    fn parseLiteral(self: *Self, content: []const u8) !context.Value {
        _ = self;

        // String literal
        if (content.len >= 2 and (content[0] == '"' or content[0] == '\'')) {
            const str_content = content[1 .. content.len - 1];
            return context.Value{ .string = str_content };
        }

        // Boolean literal
        if (std.mem.eql(u8, content, "true")) {
            return context.Value{ .boolean = true };
        }
        if (std.mem.eql(u8, content, "false")) {
            return context.Value{ .boolean = false };
        }

        // Number literal
        if (std.fmt.parseFloat(f64, content)) |num| {
            return context.Value{ .number = num };
        } else |_| {
            // Not a number, treat as string
            return context.Value{ .string = content };
        }
    }

    /// Evaluate operator expression
    fn evaluateOperatorExpression(self: *Self, node: *parser.Node) !context.Value {
        if (node.children.items.len == 1) {
            // Unary operator
            var operand = try self.evaluateExpression(node.children.items[0]);
            defer operand.deinit(self.allocator);

            if (std.mem.eql(u8, node.content, "not") or std.mem.eql(u8, node.content, "!")) {
                return context.Value{ .boolean = !operand.isTruthy() };
            }

            return try operand.clone(self.allocator);
        } else if (node.children.items.len == 2) {
            // Binary operator
            var left = try self.evaluateExpression(node.children.items[0]);
            defer left.deinit(self.allocator);

            var right = try self.evaluateExpression(node.children.items[1]);
            defer right.deinit(self.allocator);

            return try self.evaluateBinaryOperator(node.content, left, right);
        }

        return context.Value{ .null_value = {} };
    }

    /// Evaluate binary operator
    fn evaluateBinaryOperator(self: *Self, operator: []const u8, left: context.Value, right: context.Value) !context.Value {
        _ = self;

        if (std.mem.eql(u8, operator, "==")) {
            return context.Value{ .boolean = left.equals(right) };
        } else if (std.mem.eql(u8, operator, "!=")) {
            return context.Value{ .boolean = !left.equals(right) };
        } else if (std.mem.eql(u8, operator, "and")) {
            return context.Value{ .boolean = left.isTruthy() and right.isTruthy() };
        } else if (std.mem.eql(u8, operator, "or")) {
            return context.Value{ .boolean = left.isTruthy() or right.isTruthy() };
        } else if (std.mem.eql(u8, operator, "+")) {
            const left_num = left.toNumber() orelse 0;
            const right_num = right.toNumber() orelse 0;
            return context.Value{ .number = left_num + right_num };
        } else if (std.mem.eql(u8, operator, "-")) {
            const left_num = left.toNumber() orelse 0;
            const right_num = right.toNumber() orelse 0;
            return context.Value{ .number = left_num - right_num };
        } else if (std.mem.eql(u8, operator, "*")) {
            const left_num = left.toNumber() orelse 0;
            const right_num = right.toNumber() orelse 0;
            return context.Value{ .number = left_num * right_num };
        } else if (std.mem.eql(u8, operator, "/")) {
            const left_num = left.toNumber() orelse 0;
            const right_num = right.toNumber() orelse 1;
            return context.Value{ .number = left_num / right_num };
        } else if (std.mem.eql(u8, operator, "%")) {
            const left_num = left.toNumber() orelse 0;
            const right_num = right.toNumber() orelse 1;
            return context.Value{ .number = @mod(left_num, right_num) };
        } else if (std.mem.eql(u8, operator, "<")) {
            const left_num = left.toNumber() orelse 0;
            const right_num = right.toNumber() orelse 0;
            return context.Value{ .boolean = left_num < right_num };
        } else if (std.mem.eql(u8, operator, ">")) {
            const left_num = left.toNumber() orelse 0;
            const right_num = right.toNumber() orelse 0;
            return context.Value{ .boolean = left_num > right_num };
        } else if (std.mem.eql(u8, operator, "<=")) {
            const left_num = left.toNumber() orelse 0;
            const right_num = right.toNumber() orelse 0;
            return context.Value{ .boolean = left_num <= right_num };
        } else if (std.mem.eql(u8, operator, ">=")) {
            const left_num = left.toNumber() orelse 0;
            const right_num = right.toNumber() orelse 0;
            return context.Value{ .boolean = left_num >= right_num };
        }

        return context.Value{ .null_value = {} };
    }

    /// Apply filter to value
    fn applyFilter(self: *Self, value: context.Value, filter_node: *parser.Node) !context.Value {
        const filter_name = filter_node.getAttribute("name") orelse return try value.clone(self.allocator);

        if (self.tera.getFilter(filter_name)) |filter_fn| {
            // Collect filter arguments
            var args = ArrayList(context.Value).init(self.allocator);
            defer {
                for (args.items) |*arg| {
                    arg.deinit(self.allocator);
                }
                args.deinit();
            }

            for (filter_node.children.items) |arg_node| {
                const arg_value = try self.evaluateExpression(arg_node);
                try args.append(arg_value);
            }

            return try filter_fn(self.allocator, value, args.items);
        }

        // Filter not found, return original value
        return try value.clone(self.allocator);
    }

    /// Create loop context with loop variables
    fn createLoopContext(self: *Self, index: usize, total: usize) !context.Context {
        var loop_ctx = context.Context.init(self.allocator);

        try loop_ctx.set("index", context.Value{ .number = @floatFromInt(index) });
        try loop_ctx.set("index0", context.Value{ .number = @floatFromInt(index) });
        try loop_ctx.set("index1", context.Value{ .number = @floatFromInt(index + 1) });
        try loop_ctx.set("length", context.Value{ .number = @floatFromInt(total) });
        try loop_ctx.set("first", context.Value{ .boolean = index == 0 });
        try loop_ctx.set("last", context.Value{ .boolean = index == total - 1 });

        return loop_ctx;
    }
};

// Tests
const expect = std.testing.expect;

test "render simple text" {
    const allocator = std.testing.allocator;

    const root = try parser.Node.init(allocator, .template, "");
    defer {
        root.deinit(allocator);
        allocator.destroy(root);
    }

    const text_node = try parser.Node.init(allocator, .text, "Hello, World!");
    try root.addChild(text_node);

    const template = try parser.Template.init(allocator, root);

    var tera = @import("tera.zig").Tera.init(allocator);
    defer tera.deinit();

    var ctx = context.Context.init(allocator);
    defer ctx.deinit();

    var renderer = Renderer.init(allocator, &tera, ctx);
    defer renderer.deinit();

    const result = try renderer.render(template);
    defer allocator.free(result);

    try expect(std.mem.eql(u8, result, "Hello, World!"));
}

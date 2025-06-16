//! Parser for Tera templates
//! Converts tokens into an Abstract Syntax Tree (AST)

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const lexer = @import("lexer.zig");

/// AST Node types
pub const NodeType = enum {
    template,
    text,
    variable,
    tag,
    comment,
    block,
    if_statement,
    for_loop,
    filter,
    expression,
    identifier,
    literal,
    extends,
    include,
    set,
};

/// AST Node
pub const Node = struct {
    type: NodeType,
    content: []const u8,
    children: ArrayList(*Node),
    attributes: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn init(allocator: Allocator, node_type: NodeType, content: []const u8) !*Self {
        const node = try allocator.create(Self);
        node.* = Self{
            .type = node_type,
            .content = content,
            .children = ArrayList(*Node).init(allocator),
            .attributes = std.StringHashMap([]const u8).init(allocator),
        };
        return node;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        for (self.children.items) |child| {
            child.deinit(allocator);
            allocator.destroy(child);
        }
        self.children.deinit();
        self.attributes.deinit();
    }

    pub fn addChild(self: *Self, child: *Node) !void {
        try self.children.append(child);
    }

    pub fn setAttribute(self: *Self, key: []const u8, value: []const u8) !void {
        try self.attributes.put(key, value);
    }

    pub fn getAttribute(self: *Self, key: []const u8) ?[]const u8 {
        return self.attributes.get(key);
    }
};

/// Template structure containing the root AST node
pub const Template = struct {
    root: *Node,
    name: ?[]const u8,
    parent: ?[]const u8, // For template inheritance
    blocks: std.StringHashMap(*Node), // Named blocks for inheritance

    const Self = @This();

    pub fn init(allocator: Allocator, root: *Node) !Self {
        return Self{
            .root = root,
            .name = null,
            .parent = null,
            .blocks = std.StringHashMap(*Node).init(allocator),
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.root.deinit(allocator);
        allocator.destroy(self.root);
        self.blocks.deinit();
    }

    pub fn setParent(self: *Self, parent: []const u8) void {
        self.parent = parent;
    }

    pub fn addBlock(self: *Self, name: []const u8, block: *Node) !void {
        try self.blocks.put(name, block);
    }

    pub fn getBlock(self: *Self, name: []const u8) ?*Node {
        return self.blocks.get(name);
    }
};

/// Parser for converting tokens to AST
pub const Parser = struct {
    allocator: Allocator,
    tokens: []const lexer.Token,
    position: usize,

    const Self = @This();

    pub fn init(allocator: Allocator, tokens: []const lexer.Token) Self {
        return Self{
            .allocator = allocator,
            .tokens = tokens,
            .position = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        // Tokens are owned by the lexer
    }

    /// Parse tokens into a Template
    pub fn parse(self: *Self) !Template {
        const root = try Node.init(self.allocator, .template, "");
        var template = try Template.init(self.allocator, root);

        while (self.position < self.tokens.len and self.current().type != .eof) {
            const node = try self.parseNode();
            if (node) |n| {
                try root.addChild(n);

                // Handle special template-level nodes
                if (n.type == .extends) {
                    if (n.getAttribute("template")) |parent_name| {
                        template.setParent(parent_name);
                    }
                } else if (n.type == .block) {
                    if (n.getAttribute("name")) |block_name| {
                        try template.addBlock(block_name, n);
                    }
                }
            }
        }

        return template;
    }

    /// Parse a single node
    fn parseNode(self: *Self) anyerror!?*Node {
        if (self.position >= self.tokens.len) return null;

        const token = self.current();

        switch (token.type) {
            .text => {
                const node = try Node.init(self.allocator, .text, token.content);
                self.advance();
                return node;
            },
            .variable_start => {
                return try self.parseVariable();
            },
            .tag_start => {
                return try self.parseTag();
            },
            .comment_start => {
                return try self.parseComment();
            },
            .newline, .whitespace => {
                // Skip whitespace but preserve it as text if significant
                const node = try Node.init(self.allocator, .text, token.content);
                self.advance();
                return node;
            },
            else => {
                self.advance(); // Skip unknown tokens
                return null;
            },
        }
    }

    /// Parse variable: {{ variable | filter }}
    fn parseVariable(self: *Self) !*Node {
        self.expect(.variable_start);

        const node = try Node.init(self.allocator, .variable, "");

        // Skip whitespace
        self.skipWhitespace();

        // Parse the main expression
        const expr = try self.parseExpression();
        try node.addChild(expr);

        // Parse filters
        while (self.position < self.tokens.len and self.current().type == .pipe) {
            self.advance(); // Skip pipe
            self.skipWhitespace();

            const filter_node = try self.parseFilter();
            try node.addChild(filter_node);
        }

        self.skipWhitespace();
        self.expect(.variable_end);

        return node;
    }

    /// Parse tag: {% if condition %}, {% for item in list %}, etc.
    fn parseTag(self: *Self) !*Node {
        self.expect(.tag_start);
        self.skipWhitespace();

        const keyword_token = self.current();

        switch (keyword_token.type) {
            .if_kw => return try self.parseIf(),
            .for_kw => return try self.parseFor(),
            .block_kw => return try self.parseBlock(),
            .extends_kw => return try self.parseExtends(),
            .include_kw => return try self.parseInclude(),
            .set_kw => return try self.parseSet(),
            else => {
                // Generic tag
                const node = try Node.init(self.allocator, .tag, keyword_token.content);
                self.advance();

                // Parse remaining content until tag end
                var content = ArrayList(u8).init(self.allocator);
                defer content.deinit();

                while (self.position < self.tokens.len and self.current().type != .tag_end) {
                    const token = self.current();
                    try content.appendSlice(token.content);
                    self.advance();
                }

                try node.setAttribute("content", try content.toOwnedSlice());
                self.expect(.tag_end);
                return node;
            },
        }
    }

    /// Parse if statement: {% if condition %} ... {% elif condition %} ... {% else %} ... {% endif %}
    fn parseIf(self: *Self) !*Node {
        self.expect(.if_kw);

        const node = try Node.init(self.allocator, .if_statement, "");

        // Parse condition
        const condition = try self.parseExpression();
        try node.addChild(condition);

        self.skipWhitespace();
        self.expect(.tag_end);

        // Parse if body
        const if_body = try self.parseUntil(&[_]lexer.TokenType{ .elif_kw, .else_kw, .endif_kw });
        try node.addChild(if_body);

        // Parse elif/else clauses
        while (self.position < self.tokens.len) {
            const token = self.current();
            if (token.type == .elif_kw) {
                self.advance();
                const elif_condition = try self.parseExpression();
                try node.addChild(elif_condition);

                self.skipWhitespace();
                self.expect(.tag_end);

                const elif_body = try self.parseUntil(&[_]lexer.TokenType{ .elif_kw, .else_kw, .endif_kw });
                try node.addChild(elif_body);
            } else if (token.type == .else_kw) {
                self.advance();
                self.skipWhitespace();
                self.expect(.tag_end);

                const else_body = try self.parseUntil(&[_]lexer.TokenType{.endif_kw});
                try node.addChild(else_body);
                break;
            } else if (token.type == .endif_kw) {
                break;
            } else {
                break;
            }
        }

        self.expect(.tag_start);
        self.skipWhitespace();
        self.expect(.endif_kw);
        self.skipWhitespace();
        self.expect(.tag_end);

        return node;
    }

    /// Parse for loop: {% for item in list %} ... {% endfor %}
    fn parseFor(self: *Self) !*Node {
        self.expect(.for_kw);

        const node = try Node.init(self.allocator, .for_loop, "");

        self.skipWhitespace();

        // Parse loop variable
        if (self.current().type == .identifier) {
            try node.setAttribute("var", self.current().content);
            self.advance();
        }

        self.skipWhitespace();
        self.expect(.in_kw);
        self.skipWhitespace();

        // Parse iterable expression
        const iterable = try self.parseExpression();
        try node.addChild(iterable);

        self.skipWhitespace();
        self.expect(.tag_end);

        // Parse loop body
        const body = try self.parseUntil(&[_]lexer.TokenType{.endfor_kw});
        try node.addChild(body);

        self.expect(.tag_start);
        self.skipWhitespace();
        self.expect(.endfor_kw);
        self.skipWhitespace();
        self.expect(.tag_end);

        return node;
    }

    /// Parse block: {% block name %} ... {% endblock %}
    fn parseBlock(self: *Self) !*Node {
        self.expect(.block_kw);

        const node = try Node.init(self.allocator, .block, "");

        self.skipWhitespace();

        // Parse block name
        if (self.current().type == .identifier) {
            try node.setAttribute("name", self.current().content);
            self.advance();
        }

        self.skipWhitespace();
        self.expect(.tag_end);

        // Parse block body
        const body = try self.parseUntil(&[_]lexer.TokenType{.endblock_kw});
        try node.addChild(body);

        self.expect(.tag_start);
        self.skipWhitespace();
        self.expect(.endblock_kw);
        self.skipWhitespace();
        self.expect(.tag_end);

        return node;
    }

    /// Parse extends: {% extends "template.html" %}
    fn parseExtends(self: *Self) !*Node {
        self.expect(.extends_kw);

        const node = try Node.init(self.allocator, .extends, "");

        self.skipWhitespace();

        // Parse template name
        if (self.current().type == .string) {
            const template_name = self.current().content;
            // Remove quotes
            const name = template_name[1 .. template_name.len - 1];
            try node.setAttribute("template", name);
            self.advance();
        }

        self.skipWhitespace();
        self.expect(.tag_end);

        return node;
    }

    /// Parse include: {% include "template.html" %}
    fn parseInclude(self: *Self) !*Node {
        self.expect(.include_kw);

        const node = try Node.init(self.allocator, .include, "");

        self.skipWhitespace();

        // Parse template name
        if (self.current().type == .string) {
            const template_name = self.current().content;
            // Remove quotes
            const name = template_name[1 .. template_name.len - 1];
            try node.setAttribute("template", name);
            self.advance();
        }

        self.skipWhitespace();
        self.expect(.tag_end);

        return node;
    }

    /// Parse set: {% set var = value %}
    fn parseSet(self: *Self) !*Node {
        self.expect(.set_kw);

        const node = try Node.init(self.allocator, .set, "");

        self.skipWhitespace();

        // Parse variable name
        if (self.current().type == .identifier) {
            try node.setAttribute("var", self.current().content);
            self.advance();
        }

        self.skipWhitespace();
        self.expect(.equals);
        self.skipWhitespace();

        // Parse value expression
        const value = try self.parseExpression();
        try node.addChild(value);

        self.skipWhitespace();
        self.expect(.tag_end);

        return node;
    }

    /// Parse comment: {# comment #}
    fn parseComment(self: *Self) !*Node {
        self.expect(.comment_start);

        var content = ArrayList(u8).init(self.allocator);
        defer content.deinit();

        while (self.position < self.tokens.len and self.current().type != .comment_end) {
            try content.appendSlice(self.current().content);
            self.advance();
        }

        self.expect(.comment_end);

        const node = try Node.init(self.allocator, .comment, try content.toOwnedSlice());
        return node;
    }

    /// Parse expression (variables, literals, operators)
    fn parseExpression(self: *Self) anyerror!*Node {
        return try self.parseOrExpression();
    }

    /// Parse OR expression
    fn parseOrExpression(self: *Self) !*Node {
        var left = try self.parseAndExpression();

        while (self.position < self.tokens.len and self.current().type == .or_op) {
            const op_token = self.current();
            self.advance();

            const right = try self.parseAndExpression();

            const expr_node = try Node.init(self.allocator, .expression, op_token.content);
            try expr_node.addChild(left);
            try expr_node.addChild(right);
            left = expr_node;
        }

        return left;
    }

    /// Parse AND expression
    fn parseAndExpression(self: *Self) !*Node {
        var left = try self.parseEqualityExpression();

        while (self.position < self.tokens.len and self.current().type == .and_op) {
            const op_token = self.current();
            self.advance();

            const right = try self.parseEqualityExpression();

            const expr_node = try Node.init(self.allocator, .expression, op_token.content);
            try expr_node.addChild(left);
            try expr_node.addChild(right);
            left = expr_node;
        }

        return left;
    }

    /// Parse equality expression (==, !=)
    fn parseEqualityExpression(self: *Self) !*Node {
        var left = try self.parseComparisonExpression();

        while (self.position < self.tokens.len and
            (self.current().type == .equals or self.current().type == .not_equals))
        {
            const op_token = self.current();
            self.advance();

            const right = try self.parseComparisonExpression();

            const expr_node = try Node.init(self.allocator, .expression, op_token.content);
            try expr_node.addChild(left);
            try expr_node.addChild(right);
            left = expr_node;
        }

        return left;
    }

    /// Parse comparison expression (<, >, <=, >=)
    fn parseComparisonExpression(self: *Self) !*Node {
        var left = try self.parseAdditionExpression();

        while (self.position < self.tokens.len and
            (self.current().type == .less_than or self.current().type == .greater_than or
                self.current().type == .less_equal or self.current().type == .greater_equal))
        {
            const op_token = self.current();
            self.advance();

            const right = try self.parseAdditionExpression();

            const expr_node = try Node.init(self.allocator, .expression, op_token.content);
            try expr_node.addChild(left);
            try expr_node.addChild(right);
            left = expr_node;
        }

        return left;
    }

    /// Parse addition expression (+, -)
    fn parseAdditionExpression(self: *Self) !*Node {
        var left = try self.parseMultiplicationExpression();

        while (self.position < self.tokens.len and
            (self.current().type == .plus or self.current().type == .minus))
        {
            const op_token = self.current();
            self.advance();

            const right = try self.parseMultiplicationExpression();

            const expr_node = try Node.init(self.allocator, .expression, op_token.content);
            try expr_node.addChild(left);
            try expr_node.addChild(right);
            left = expr_node;
        }

        return left;
    }

    /// Parse multiplication expression (*, /, %)
    fn parseMultiplicationExpression(self: *Self) !*Node {
        var left = try self.parseUnaryExpression();

        while (self.position < self.tokens.len and
            (self.current().type == .multiply or self.current().type == .divide or
                self.current().type == .modulo))
        {
            const op_token = self.current();
            self.advance();

            const right = try self.parseUnaryExpression();

            const expr_node = try Node.init(self.allocator, .expression, op_token.content);
            try expr_node.addChild(left);
            try expr_node.addChild(right);
            left = expr_node;
        }

        return left;
    }

    /// Parse unary expression (not, !)
    fn parseUnaryExpression(self: *Self) !*Node {
        if (self.position < self.tokens.len and self.current().type == .not_op) {
            const op_token = self.current();
            self.advance();

            const operand = try self.parseUnaryExpression();

            const expr_node = try Node.init(self.allocator, .expression, op_token.content);
            try expr_node.addChild(operand);
            return expr_node;
        }

        return try self.parsePrimaryExpression();
    }

    /// Parse primary expression (literals, identifiers, parentheses)
    fn parsePrimaryExpression(self: *Self) !*Node {
        const token = self.current();
        switch (token.type) {
            .identifier => {
                const node = try Node.init(self.allocator, .identifier, token.content);
                self.advance();

                // Handle dot notation for member access
                while (self.position < self.tokens.len and self.current().type == .dot) {
                    self.advance(); // Skip dot

                    if (self.current().type == .identifier) {
                        const member_node = try Node.init(self.allocator, .identifier, self.current().content);
                        try node.addChild(member_node);
                        self.advance();
                    }
                }

                return node;
            },
            .string, .number, .boolean => {
                const node = try Node.init(self.allocator, .literal, token.content);
                self.advance();
                return node;
            },
            .left_paren => {
                self.advance(); // Skip (
                const expr = try self.parseExpression();
                self.expect(.right_paren);
                return expr;
            },
            else => {
                // Error: unexpected token
                const node = try Node.init(self.allocator, .literal, "");
                return node;
            },
        }
    }

    /// Parse filter: filter_name(args)
    fn parseFilter(self: *Self) !*Node {
        const node = try Node.init(self.allocator, .filter, "");

        if (self.current().type == .identifier) {
            try node.setAttribute("name", self.current().content);
            self.advance();

            // Parse filter arguments if present
            if (self.position < self.tokens.len and self.current().type == .left_paren) {
                self.advance(); // Skip (

                while (self.position < self.tokens.len and self.current().type != .right_paren) {
                    const arg = try self.parseExpression();
                    try node.addChild(arg);

                    if (self.current().type == .comma) {
                        self.advance(); // Skip comma
                        self.skipWhitespace();
                    }
                }

                self.expect(.right_paren);
            }
        }

        return node;
    }

    /// Parse until one of the specified token types
    fn parseUntil(self: *Self, end_tokens: []const lexer.TokenType) !*Node {
        const body = try Node.init(self.allocator, .template, "");

        while (self.position < self.tokens.len) {
            // Check if we've reached an end token
            const current_token = self.current();
            var found_end = false;

            if (current_token.type == .tag_start) {
                // Look ahead to see if the next token is an end token
                if (self.position + 1 < self.tokens.len) {
                    const next_token = self.tokens[self.position + 1];
                    for (end_tokens) |end_type| {
                        if (next_token.type == end_type) {
                            found_end = true;
                            break;
                        }
                    }
                }
            }

            if (found_end) break;

            const node = try self.parseNode();
            if (node) |n| {
                try body.addChild(n);
            }
        }

        return body;
    }

    /// Get current token
    fn current(self: *Self) lexer.Token {
        if (self.position >= self.tokens.len) {
            return lexer.Token{ .type = .eof, .content = "", .line = 0, .column = 0 };
        }
        return self.tokens[self.position];
    }

    /// Advance to next token
    fn advance(self: *Self) void {
        if (self.position < self.tokens.len) {
            self.position += 1;
        }
    }

    /// Expect a specific token type
    fn expect(self: *Self, expected: lexer.TokenType) void {
        const token = self.current();
        if (token.type == expected) {
            self.advance();
        }
        // In a production parser, this would throw an error
    }

    /// Skip whitespace tokens
    fn skipWhitespace(self: *Self) void {
        while (self.position < self.tokens.len and
            (self.current().type == .whitespace or self.current().type == .newline))
        {
            self.advance();
        }
    }
};

// Tests
const expect = std.testing.expect;

test "parse simple variable" {
    const allocator = std.testing.allocator;

    var lexer_instance = lexer.Lexer.init(allocator, "{{ name }}");
    defer lexer_instance.deinit();

    const tokens = try lexer_instance.tokenize();
    defer allocator.free(tokens);

    var parser = Parser.init(allocator, tokens);
    defer parser.deinit();

    var template = try parser.parse();
    defer template.deinit(allocator);

    try expect(template.root.children.items.len > 0);
    try expect(template.root.children.items[0].type == .variable);
}

test "parse nested variable" {
    const allocator = std.testing.allocator;

    var lexer_instance = lexer.Lexer.init(allocator, "{{ name.value }}");
    defer lexer_instance.deinit();

    const tokens = try lexer_instance.tokenize();
    defer allocator.free(tokens);

    var parser = Parser.init(allocator, tokens);
    defer parser.deinit();

    var template = try parser.parse();
    defer template.deinit(allocator);

    try expect(template.root.children.items.len > 0);
    try expect(template.root.children.items[2].type == .variable);
}

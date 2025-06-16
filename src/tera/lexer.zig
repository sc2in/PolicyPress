//! Lexer for Tera templates
//! Tokenizes template strings into a stream of tokens for parsing

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

/// Token types for Tera templates
pub const TokenType = enum {
    // Literals
    text, // Plain text content
    variable_start, // {{
    variable_end, // }}
    tag_start, // {%
    tag_end, // %}
    comment_start, // {#
    comment_end, // #}

    // Identifiers and values
    identifier, // variable names, keywords
    string, // "string literal"
    number, // 42, 3.14
    boolean, // true, false

    // Operators
    pipe, // |
    dot, // .
    equals, // =
    not_equals, // !=
    less_than, // <
    greater_than, // >
    less_equal, // <=
    greater_equal, // >=
    plus, // +
    minus, // -
    multiply, // *
    divide, // /
    modulo, // %
    and_op, // and
    or_op, // or
    not_op, // not

    // Delimiters
    left_paren, // (
    right_paren, // )
    left_bracket, // [
    right_bracket, // ]
    comma, // ,

    // Keywords
    if_kw, // if
    else_kw, // else
    elif_kw, // elif
    endif_kw, // endif
    for_kw, // for
    endfor_kw, // endfor
    in_kw, // in
    block_kw, // block
    endblock_kw, // endblock
    extends_kw, // extends
    include_kw, // include
    set_kw, // set
    macro_kw, // macro
    endmacro_kw, // endmacro
    filter_kw, // filter
    endfilter_kw, // endfilter

    // Special
    eof, // End of file
    newline, // \n
    whitespace, // spaces, tabs
};

/// Token struct containing type, content, and position
pub const Token = struct {
    type: TokenType,
    content: []const u8,
    line: u32,
    column: u32,

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Token({s}: '{s}' at {}:{})", .{ @tagName(self.type), self.content, self.line, self.column });
    }
};

/// Lexer for tokenizing Tera templates
pub const Lexer = struct {
    allocator: Allocator,
    input: []const u8,
    position: usize,
    line: u32,
    column: u32,
    tokens: ArrayList(Token),
    open: bool = false,

    const Self = @This();

    pub fn init(allocator: Allocator, input: []const u8) Self {
        return Self{
            .allocator = allocator,
            .input = input,
            .position = 0,
            .line = 1,
            .column = 1,
            .tokens = ArrayList(Token).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    /// Tokenize the entire input
    pub fn tokenize(self: *Self) ![]Token {
        while (self.position < self.input.len) {
            try self.nextToken();
        }

        // Add EOF token
        try self.addToken(.eof, "");

        return self.tokens.toOwnedSlice();
    }

    /// Get the next token
    fn nextToken(self: *Self) !void {
        if (self.position >= self.input.len) return;

        const start_pos = self.position;
        const char = self.current();
        // const last = self.tokens.getLastOrNull();

        // Check for template delimiters first
        if (char == '{') {
            if (self.peek(1) == '{') {
                self.open = true;
                try self.addToken(.variable_start, self.input[start_pos .. self.position + 2]);
                self.advance();
                self.advance();
                return;
            } else if (self.peek(1) == '%') {
                self.open = true;

                try self.addToken(.tag_start, self.input[start_pos .. self.position + 2]);
                self.advance();
                self.advance();
                return;
            } else if (self.peek(1) == '#') {
                self.open = true;

                try self.addToken(.comment_start, self.input[start_pos .. self.position + 2]);
                self.advance();
                self.advance();
                return;
            }
        } else if (char == '}') {
            if (self.peek(1) == '}') {
                self.open = false;

                try self.addToken(.variable_end, self.input[start_pos .. self.position + 2]);
                self.advance();
                self.advance();
                return;
            }
        } else if (char == '%' and self.peek(1) == '}') {
            self.open = false;

            try self.addToken(.tag_end, self.input[start_pos .. self.position + 2]);
            self.advance();
            self.advance();
            return;
        } else if (char == '#' and self.peek(1) == '}') {
            self.open = false;

            try self.addToken(.comment_end, self.input[start_pos .. self.position + 2]);
            self.advance();
            self.advance();
            return;
        }
        if (self.open) {

            // Handle other characters
            switch (char) {
                ' ', '\t' => {
                    try self.whitespace();
                },
                '\n' => {
                    try self.addToken(.newline, self.input[start_pos .. self.position + 1]);
                    self.advance();
                    self.line += 1;
                    self.column = 1;
                },
                '|' => {
                    try self.addToken(.pipe, "|");
                    self.advance();
                },
                '.' => {
                    try self.addToken(.dot, ".");
                    self.advance();
                },
                '=' => {
                    if (self.peek(1) == '=') {
                        try self.addToken(.equals, "==");
                        self.advance();
                        self.advance();
                    } else {
                        try self.addToken(.equals, "=");
                        self.advance();
                    }
                },
                '!' => {
                    if (self.peek(1) == '=') {
                        try self.addToken(.not_equals, "!=");
                        self.advance();
                        self.advance();
                    } else {
                        try self.addToken(.not_op, "!");
                        self.advance();
                    }
                },
                '<' => {
                    if (self.peek(1) == '=') {
                        try self.addToken(.less_equal, "<=");
                        self.advance();
                        self.advance();
                    } else {
                        try self.addToken(.less_than, "<");
                        self.advance();
                    }
                },
                '>' => {
                    if (self.peek(1) == '=') {
                        try self.addToken(.greater_equal, ">=");
                        self.advance();
                        self.advance();
                    } else {
                        try self.addToken(.greater_than, ">");
                        self.advance();
                    }
                },
                '+' => {
                    try self.addToken(.plus, "+");
                    self.advance();
                },
                '-' => {
                    try self.addToken(.minus, "-");
                    self.advance();
                },
                '*' => {
                    try self.addToken(.multiply, "*");
                    self.advance();
                },
                '/' => {
                    try self.addToken(.divide, "/");
                    self.advance();
                },
                '%' => {
                    try self.addToken(.modulo, "%");
                    self.advance();
                },
                '(' => {
                    try self.addToken(.left_paren, "(");
                    self.advance();
                },
                ')' => {
                    try self.addToken(.right_paren, ")");
                    self.advance();
                },
                '[' => {
                    try self.addToken(.left_bracket, "[");
                    self.advance();
                },
                ']' => {
                    try self.addToken(.right_bracket, "]");
                    self.advance();
                },
                ',' => {
                    try self.addToken(.comma, ",");
                    self.advance();
                },
                '"', '\'' => {
                    try self.string(char);
                },
                '0'...'9' => {
                    try self.number();
                },
                'a'...'z', 'A'...'Z', '_' => {
                    if (self.open) try self.identifier() else try self.text();
                },
                else => {
                    // Treat as text
                    try self.text();
                },
            }
        } else try self.text();
    }

    /// Handle whitespace
    fn whitespace(self: *Self) !void {
        // const start_pos = self.position;
        while (self.position < self.input.len and (self.current() == ' ' or self.current() == '\t')) {
            self.advance();
        }
        //  ignore
        //        try self.addToken(.whitespace, self.input[start_pos..self.position]);
    }

    /// Handle string literals
    fn string(self: *Self, quote: u8) !void {
        const start_pos = self.position;
        self.advance(); // Skip opening quote

        while (self.position < self.input.len and self.current() != quote) {
            if (self.current() == '\\') {
                self.advance(); // Skip escape character
                if (self.position < self.input.len) {
                    self.advance(); // Skip escaped character
                }
            } else {
                self.advance();
            }
        }

        if (self.position < self.input.len) {
            self.advance(); // Skip closing quote
        }

        try self.addToken(.string, self.input[start_pos..self.position]);
    }

    /// Handle numbers (integers and floats)
    fn number(self: *Self) !void {
        const start_pos = self.position;

        while (self.position < self.input.len and std.ascii.isDigit(self.current())) {
            self.advance();
        }

        // Handle decimal point
        if (self.position < self.input.len and self.current() == '.' and
            self.position + 1 < self.input.len and std.ascii.isDigit(self.peek(1)))
        {
            self.advance(); // Skip '.'
            while (self.position < self.input.len and std.ascii.isDigit(self.current())) {
                self.advance();
            }
        }

        try self.addToken(.number, self.input[start_pos..self.position]);
    }

    /// Handle identifiers and keywords
    fn identifier(self: *Self) !void {
        const start_pos = self.position;

        while (self.position < self.input.len and
            (std.ascii.isAlphanumeric(self.current()) or self.current() == '_'))
        {
            self.advance();
        }

        const content = self.input[start_pos..self.position];
        const token_type = self.getKeywordType(content);

        try self.addToken(token_type, content);
    }

    /// Handle plain text
    fn text(self: *Self) !void {
        const start_pos = self.position;

        // Consume text until we hit a template delimiter or EOF
        while (self.position < self.input.len) {
            const char = self.current();

            // Check for start of template delimiters
            if (char == '{' and self.position + 1 < self.input.len) {
                const next_char = self.peek(1);
                if (next_char == '{' or next_char == '%' or next_char == '#') {
                    break;
                }
            }

            self.advance();
        }

        if (self.position > start_pos) {
            try self.addToken(.text, self.input[start_pos..self.position]);
        }
    }

    /// Get keyword type for identifier
    fn getKeywordType(self: *Self, content: []const u8) TokenType {
        _ = self;

        const keywords = std.StaticStringMap(TokenType).initComptime(.{
            .{ "if", .if_kw },
            .{ "else", .else_kw },
            .{ "elif", .elif_kw },
            .{ "endif", .endif_kw },
            .{ "for", .for_kw },
            .{ "endfor", .endfor_kw },
            .{ "in", .in_kw },
            .{ "block", .block_kw },
            .{ "endblock", .endblock_kw },
            .{ "extends", .extends_kw },
            .{ "include", .include_kw },
            .{ "set", .set_kw },
            .{ "macro", .macro_kw },
            .{ "endmacro", .endmacro_kw },
            .{ "filter", .filter_kw },
            .{ "endfilter", .endfilter_kw },
            .{ "and", .and_op },
            .{ "or", .or_op },
            .{ "not", .not_op },
            .{ "true", .boolean },
            .{ "false", .boolean },
        });

        return keywords.get(content) orelse .identifier;
    }

    /// Add a token to the list
    fn addToken(self: *Self, token_type: TokenType, content: []const u8) !void {
        try self.tokens.append(Token{
            .type = token_type,
            .content = content,
            .line = self.line,
            .column = self.column -| @as(u32, @intCast(content.len)),
        });
    }

    /// Get current character
    fn current(self: *Self) u8 {
        if (self.position >= self.input.len) return 0;
        return self.input[self.position];
    }

    /// Peek ahead n characters
    fn peek(self: *Self, offset: usize) u8 {
        const pos = self.position + offset;
        if (pos >= self.input.len) return 0;
        return self.input[pos];
    }

    /// Advance to next character
    fn advance(self: *Self) void {
        if (self.position < self.input.len) {
            self.position += 1;
            self.column += 1;
        }
    }
};

// Tests
const expect = std.testing.expect;
const tst = std.testing;
test "basic tokenization" {
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, "Hello {{ name }}!");
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    try expect(tokens.len >= 4);
    for (tokens) |t|
        std.debug.print("{}\n", .{t});
    try tst.expectEqual(.text, tokens[0].type);
    try tst.expectEqual(.variable_start, tokens[1].type);
    try tst.expectEqual(.identifier, tokens[3].type);
}

test "template tags" {
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, "{% if user %}Hello{% endif %}");
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    var found_if = false;
    var found_endif = false;

    for (tokens) |token| {
        if (token.type == .if_kw) found_if = true;
        if (token.type == .endif_kw) found_endif = true;
    }

    try expect(found_if);
    try expect(found_endif);
}

const std = @import("std");
const Token = @import("lexer.zig");
const print = std.debug.print;
const allocator = std.heap.page_allocator;
const AST = @This();

// Grammar:
// <program> ::= <function>
// <function> ::= "int" <id> "(" ")" "{" <statement> "}"
// <statement> ::= "return" <exp> ";"
// <exp> ::= <int>
const TYPE = enum { int, char, cstring };
const AST_PROGRAM = struct { function: []AST_FUNCTION };
const AST_FUNCTION = struct { type: TYPE = .int, name: []const u8, body: []AST_STATEMENT };
const AST_STATEMENT = union(enum) {
    @"return": struct { rc: usize },
    call: struct { fname: []const u8, args: *anyopaque },
};
const AST_EXPRESSION = union(TYPE) {
    int: usize,
    char: u8,
    cstring: [*:0]u8,
};

program: AST_PROGRAM,
tokenlist: Token.TokenList,
var line: usize = 0; // contains last parsed line

// <program> ::= <function>
fn parseProgram(self: *AST) !void {
    const function = try self.parseFunction();
    // TODO: figure out how many functions
    var functions = try allocator.alloc(AST_FUNCTION, 1);
    functions[0] = function;
    self.program = .{ .function = functions };
}

// <function> ::= "int" <id> "(" ")" "{" <statement> "}"
fn parseFunction(self: *AST) !AST_FUNCTION {
    _ = try self.parseExpect(.keyword, "int");

    const tok = try self.parseExpect(.identifier, "main");
    const fnname = try allocator.dupe(u8, tok.kind.identifier);
    line = tok.line;

    _ = try self.parseExpect(.lpar, null);
    _ = try self.parseExpect(.rpar, null);
    _ = try self.parseExpect(.lcbra, null);
    const statement = try self.parseStatement();
    _ = try self.parseExpect(.rcbra, null);

    // TODO: figure out how many statement per function
    var statements = try allocator.alloc(AST_STATEMENT, 1);
    statements[0] = statement;
    return AST_FUNCTION{ .name = fnname, .body = statements };
}

// <statement> ::= "return" <exp> ";"
fn parseStatement(self: *AST) !AST_STATEMENT {
    _ = try self.parseExpect(.keyword, @tagName(AST_STATEMENT.@"return"));
    const expression = try self.parseExpression();
    _ = try self.parseExpect(.semicolon, null);
    return AST_STATEMENT{ .@"return" = .{ .rc = expression.int } };
}

// <exp> ::= <int>
fn parseExpression(self: *AST) !AST_EXPRESSION {
    const tok = try self.parseExpect(.number, null);
    return AST_EXPRESSION{ .int = tok.kind.number };
}

// help making code shorter by making a general expect token
fn parseExpect(self: *AST, kind: Token.TokenKind, str: ?[]const u8) !Token {
    const tok = self.tokenlist.popOrNull() orelse fail(null, error.MissingToken);
    const err = switch (kind) {
        .semicolon => error.ExpectedSemicolon,
        .identifier => error.ExpectedIdentifier,
        .keyword => error.ExpectedKeyword,
        .lpar => error.ExpectedLeftParenthesis,
        .rpar => error.ExpectedRightParenthesis,
        .lcbra => error.ExpectedLeftCulryBrace,
        .rcbra => error.ExpectedRightCurlyBrace,
        .number => error.ExpectedNumber,
    };
    if (tok.kind != kind) fail(tok, err);
    if (kind == .identifier and !std.mem.eql(u8, tok.kind.identifier, str.?)) fail(tok, err);
    if (kind == .keyword and !std.mem.eql(u8, tok.kind.keyword, str.?)) fail(tok, err);
    line = tok.line;
    return tok;
}

// show an error code with the line number in the code
fn fail(token: ?Token, err: anyerror) noreturn {
    if (token) |tok| {
        print("error on line {d}: {s} but got {s}\n", .{ tok.line, @errorName(err), @tagName(tok.kind) });
    } else {
        print("error on line {d}: {s}\n", .{ line, @errorName(err) });
    }
    std.process.exit(1);
}

// Pretty Print AST
pub fn pp(self: AST) void {
    for (self.program.function) |function| {
        print(
            \\FUNC int {s}:
            \\  params: ()
            \\  body:
            \\
        , .{function.name});

        for (function.body) |statement| {
            switch (statement) {
                .@"return" => |ret| {
                    print(
                        \\      RET {d}
                        \\
                    , .{ret.rc});
                },
                .call => |call| {
                    print(
                        \\      CALL {s}, ...
                        \\
                    , .{call.fname});
                },
            }
        }
    }
}

// Parse tokens to generate AST
pub fn parse(tokens: []Token) !AST {
    var tokenlist = try Token.TokenList.initCapacity(allocator, tokens.len);
    std.mem.reverse(Token, tokens);
    tokenlist.insertSlice(0, tokens) catch unreachable;

    var ast: AST = undefined;
    ast.tokenlist = tokenlist;
    try ast.parseProgram();
    return ast;
}

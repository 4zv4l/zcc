const std = @import("std");
const lexer = @import("lexer.zig");
const print = std.debug.print;
const allocator = std.heap.page_allocator;

// Grammar:
// <program> ::= <function>
// <function> ::= "int" <id> "(" ")" "{" <statement> "}"
// <statement> ::= "return" <exp> ";"
// <exp> ::= <int>
const AST_PROGRAM = struct { function: AST_FUNCTION };
const AST_FUNCTION = struct { name: []const u8, body: AST_STATEMENT };
const AST_STATEMENT = struct { name: []const u8, expression: AST_EXPRESSION };
const AST_EXPRESSION = struct { number: usize };
const AST = struct {
    program: AST_PROGRAM,
    tokenlist: lexer.TokenList,
    var line: usize = 0;

    fn parseProgram(self: *AST) !void {
        const function = try self.parseFunction();
        self.program = .{ .function = function };
    }

    fn parseFunction(self: *AST) !AST_FUNCTION {
        var tok = self.tokenlist.popOrNull() orelse fail(null, error.MissingToken);
        if (tok.kind != .keyword or !std.mem.eql(u8, tok.str.?, "int")) fail(tok, error.ExpectedInt);
        line = tok.line;

        tok = self.tokenlist.popOrNull() orelse fail(null, error.MissingToken);
        if (tok.kind != .identifier or !std.mem.eql(u8, tok.str.?, "main")) fail(tok, error.ExpectedMain);
        const fnname = try allocator.dupe(u8, tok.str.?);
        line = tok.line;

        tok = self.tokenlist.popOrNull() orelse fail(null, error.MissingToken);
        if (tok.kind != .lpar) fail(tok, error.ExpectedLeftParenthesis);
        line = tok.line;
        tok = self.tokenlist.popOrNull() orelse fail(null, return error.MissingToken);
        if (tok.kind != .rpar) fail(tok, error.ExpectedRightParenthesis);
        line = tok.line;

        tok = self.tokenlist.popOrNull() orelse fail(null, return error.MissingToken);
        if (tok.kind != .lcbra) fail(tok, error.ExpectedLeftCulryBrace);
        line = tok.line;

        const statement = try self.parseStatement();

        tok = self.tokenlist.popOrNull() orelse fail(null, error.MissingToken);
        if (tok.kind != .rcbra) fail(tok, error.ExpectedRightCurlyBrace);
        line = tok.line;

        return AST_FUNCTION{ .name = fnname, .body = statement };
    }

    fn parseStatement(self: *AST) !AST_STATEMENT {
        var tok = self.tokenlist.popOrNull() orelse fail(null, error.MissingToken);
        if (tok.kind != .keyword or !std.mem.eql(u8, tok.str.?, "return")) return fail(tok, error.ExpectedReturn);
        const statname = try allocator.dupe(u8, tok.str.?);
        line = tok.line;

        const expression = try self.parseExpression();

        tok = self.tokenlist.popOrNull() orelse fail(tok, error.MissingToken);
        if (tok.kind != .semicolon) fail(tok, error.ExpectedSemicolon);
        line = tok.line;

        return AST_STATEMENT{ .expression = expression, .name = statname };
    }

    fn parseExpression(self: *AST) !AST_EXPRESSION {
        const tok = self.tokenlist.popOrNull() orelse fail(null, error.MissingToken);
        if (tok.kind != .number) fail(tok, error.ExpectedNumber);
        return AST_EXPRESSION{ .number = tok.num.? };
    }

    fn fail(token: ?lexer.Token, err: anyerror) noreturn {
        if (token) |tok| {
            print("error on line {d}: {s} but got {s}\n", .{ tok.line, @errorName(err), @tagName(tok.kind) });
        } else {
            print("error on line {d}: {s}\n", .{ line, @errorName(err) });
        }
        std.process.exit(1);
    }

    // Pretty Print AST
    fn pp(self: AST) void {
        print(
            \\FUN int {s}:
            \\  params: ()
            \\  body:
            \\      {s} Int<{d}>
            \\
        , .{ self.program.function.name, self.program.function.body.name, self.program.function.body.expression.number });
    }
};

// Parse tokens to generate AST
fn parse(tokens: []lexer.Token) !AST {
    var tokenlist = try lexer.TokenList.initCapacity(allocator, tokens.len);
    std.mem.reverse(lexer.Token, tokens);
    tokenlist.insertSlice(0, tokens) catch unreachable;

    var ast: AST = undefined;
    ast.tokenlist = tokenlist;
    try ast.parseProgram();
    return ast;
}

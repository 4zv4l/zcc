const std = @import("std");
const print = std.debug.print;
const allocator = std.heap.page_allocator;
const Token = @This();

pub const TokenList = std.ArrayList(Token);
// TODO: add support for string literal
pub const TokenKind = enum {
    keyword,
    identifier,
    number,
    lpar,
    rpar,
    lcbra,
    rcbra,
    semicolon,
};
pub const Keywords = &[_][]const u8{ "int", "return" };

// keyword: int | return
// identifier: [a-zA-Z]
// lpar: (
// rpar: )
// lcbra: {
// rcbra: }
// number: [0-9]
// semicolon: ;

line: usize,
kind: union(TokenKind) {
    keyword: []const u8,
    identifier: []const u8,
    number: usize,
    lpar: bool,
    rpar: bool,
    lcbra: bool,
    rcbra: bool,
    semicolon: bool,
},

/// debug function
pub fn dprint(tokens: []Token) void {
    // show tokens
    for (tokens) |tok| {
        switch (tok.kind) {
            .keyword => print("keyword: {s}\n", .{tok.kind.keyword}),
            .identifier => print("identifier: {s}\n", .{tok.kind.identifier}),
            .number => print("number: {d}\n", .{tok.kind.number}),
            else => print("{s}\n", .{@tagName(tok.kind)}),
        }
    }
}

// Check if value is reserved keyword
fn lexKeywordOrIdentifier(value: []const u8, token: *TokenList, line: usize) !void {
    for (Keywords) |elem| {
        if (std.mem.eql(u8, elem, value)) { // is a keyword
            try token.append(Token{ .kind = .{ .keyword = try allocator.dupe(u8, value) }, .line = line });
            return;
        }
    }
    try token.append(Token{ .kind = .{ .identifier = try allocator.dupe(u8, value) }, .line = line });
}

/// Parse a number (10, 0xA, 0b1010, 0o12)
/// TODO: fix hex letter not allowed
fn lex_number(word: []const u8, token: *TokenList, line: usize) !usize {
    const end_idx = blk: { // get index of when number ends
        var i: usize = 0;
        for (word) |c| {
            if (i == 1 and (c == 'x' or c == 'b' or c == 'o')) {
                i += 1;
                continue;
            }
            if (c >= '0' and c <= '9') i += 1 else break;
        }
        break :blk i;
    };
    const num: usize = std.fmt.parseUnsigned(usize, word[0..end_idx], 0) catch unreachable;
    try token.append(Token{ .kind = .{ .number = num }, .line = line });
    return end_idx;
}

// Lex any off {}();
fn lex_lr(char: u8, token: *TokenList, line: usize) !bool {
    switch (char) {
        '{' => try token.append(Token{ .kind = .{ .lcbra = true }, .line = line }),
        '}' => try token.append(Token{ .kind = .{ .rcbra = true }, .line = line }),
        '(' => try token.append(Token{ .kind = .{ .lpar = true }, .line = line }),
        ')' => try token.append(Token{ .kind = .{ .rpar = true }, .line = line }),
        ';' => try token.append(Token{ .kind = .{ .semicolon = true }, .line = line }),
        else => return false,
    }
    return true;
}

// main parser loop
pub fn lex(data: []const u8) ![]Token {
    var token = std.ArrayList(Token).init(allocator);
    var line_iterator = std.mem.tokenizeScalar(u8, data, '\n');
    var line_number: usize = 1;

    while (line_iterator.next()) |line| {
        defer line_number += 1;
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |word| {
            var idx: usize = 0;
            while (idx < word.len) {
                // if left/right {}()
                if (try lex_lr(word[idx], &token, line_number)) {
                    idx += 1;
                    continue;
                }

                // if number
                if (word[idx] >= '0' and word[idx] <= '9') {
                    const end_idx = try lex_number(word[idx..], &token, line_number);
                    idx += end_idx;
                    continue;
                }

                // if identifier/keyword (can parse number/keyword/... if they are attached (ex: main(){return}))
                var beg: usize = 0;
                var end: usize = 0;
                while (end != word[idx..].len) {
                    // if doesnt contain {}() continue looping
                    if (!std.mem.containsAtLeast(u8, "{}();", 1, &[_]u8{word[end]})) {
                        end += 1;
                        continue;
                    }
                    // if contains {}() and scanned before, add identifier and then {}() to token
                    if (std.mem.containsAtLeast(u8, "{}();", 1, &[_]u8{word[end]}) and (end > beg)) {
                        try lexKeywordOrIdentifier(word[beg..end], &token, line_number);
                        _ = try lex_lr(word[end], &token, line_number);
                        end += 1;
                        beg = end;
                        continue;
                        // if contains {}() and didnt scan before, add {}()
                    } else {
                        _ = try lex_lr(word[end], &token, line_number);
                        beg += 1;
                        end += 1;
                        continue;
                    }
                }
                // if reached end of word but have data, add token
                if (beg < end) {
                    try lexKeywordOrIdentifier(word[beg..end], &token, line_number);
                }
                idx += word[idx..].len;
            }
        }
    }
    return try token.toOwnedSlice();
}

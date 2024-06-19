const std = @import("std");
const print = std.debug.print;
const allocator = std.heap.page_allocator;

// int main() {
//  return 0;
// }
// ------------
// _main:
//  mov $0, %rax
//  ret

// keyword: int | return
// identifier: [a-zA-Z]
// lpar: (
// rpar: )
// lcbra: {
// rcbra: }
// number: [0-9]
// semicolon: ;

pub const Token = struct {
    str: ?[]const u8 = null,
    num: ?usize = null,
    kind: enum { keyword, identifier, lpar, rpar, lcbra, rcbra, number, semicolon },
    line: usize,
};
pub const TokenList = std.ArrayList(Token);

const Keywords = &[_][]const u8{ "int", "return" };

fn isKeyword(value: []const u8) bool {
    for (Keywords) |elem| {
        if (std.mem.eql(u8, elem, value)) {
            return true;
        }
    }
    return false;
}

/// Lex source code into tokens
fn lex_number(word: []const u8, token: *TokenList, line: usize) !usize {
    const end_idx = blk: {
        var i: usize = 0;
        for (word) |c| {
            if (c >= '0' and c <= '9') i += 1 else break;
        }
        break :blk i;
    };
    const num: usize = std.fmt.parseUnsigned(usize, word[0..end_idx], 0) catch unreachable;
    try token.append(Token{ .kind = .number, .num = num, .line = line });
    return end_idx;
}

// Lex any off {}();
fn lex_lr(char: u8, token: *TokenList, line: usize) !bool {
    switch (char) {
        '{' => try token.append(Token{ .kind = .lcbra, .line = line }),
        '}' => try token.append(Token{ .kind = .rcbra, .line = line }),
        '(' => try token.append(Token{ .kind = .lpar, .line = line }),
        ')' => try token.append(Token{ .kind = .rpar, .line = line }),
        ';' => try token.append(Token{ .kind = .semicolon, .line = line }),
        else => return false,
    }
    return true;
}

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

                // if keyword
                if (isKeyword(word[idx..])) {
                    try token.append(Token{ .kind = .keyword, .str = try allocator.dupe(u8, word[idx..]), .line = line_number });
                    idx += word[idx..].len;
                    continue;
                }

                // if identifier
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
                        if (isKeyword(word[beg..end])) {
                            try token.append(Token{ .kind = .keyword, .str = try allocator.dupe(u8, word[beg..end]), .line = line_number });
                        } else {
                            try token.append(Token{ .kind = .identifier, .str = try allocator.dupe(u8, word[beg..end]), .line = line_number });
                        }
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
                    if (isKeyword(word[beg..end])) {
                        try token.append(Token{ .kind = .keyword, .str = try allocator.dupe(u8, word[beg..end]), .line = line_number });
                    } else {
                        try token.append(Token{ .kind = .identifier, .str = try allocator.dupe(u8, word[beg..end]), .line = line_number });
                    }
                }
                idx += word[idx..].len;
            }
        }
    }
    return try token.toOwnedSlice();
}

// debug function
pub fn pp(tokens: []Token) void {
    // show tokens
    for (tokens) |tok| {
        switch (tok.kind) {
            .keyword => print("keyword: {s}\n", .{tok.str.?}),
            .identifier => print("identifier: {s}\n", .{tok.str.?}),
            .number => print("number: {d}\n", .{tok.num.?}),
            else => print("{s}\n", .{@tagName(tok.kind)}),
        }
    }
}

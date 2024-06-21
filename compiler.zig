const std = @import("std");
const Token = @import("lexer.zig");
const AST = @import("ast.zig");
const Generator = @import("./generate.zig");
const print = std.debug.print;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        print("usage: {s} [file.c]\n", .{args[0]});
        return;
    }

    const filepath = args[1];
    const source = try std.fs.cwd().readFileAlloc(allocator, filepath, std.math.maxInt(usize));

    // parse tokens from source file
    const tokens = try Token.lex(source);

    // generate Abstract Syntax Tree
    const abstract_tree = try AST.parse(tokens);
    abstract_tree.pp();

    // generate assembly file
    var outfile = try std.fs.cwd().createFile("out.s", .{});
    defer outfile.close();
    try Generator.generate(abstract_tree, outfile.writer());

    // use cc to compile .s file
    var cc = std.process.Child.init(&[_][]const u8{ "cc", "-o", "out", "out.s" }, allocator);
    _ = try cc.spawnAndWait();
}

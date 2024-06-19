const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");
const print = std.debug.print;
const allocator = std.heap.page_allocator;

/// Generate asm code from AST
/// TODO: rewrite to be more generic function
fn generate(a: ast.AST, writer: anytype) !void {
    try writer.print(
        \\.globl _{0s}
        \\_{0s}:
        \\  mov w0, #{1d}
        \\  ret
        \\
    , .{ a.program.function.name, a.program.function.body.expression.number });
}

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
    const tokens = try lexer.lex(source);

    // generate Abstract Syntax Tree
    const abstract_tree = try ast.parse(tokens);
    abstract_tree.pp();

    // generate assembly file
    var outfile = try std.fs.cwd().createFile("out.s", .{});
    defer outfile.close();
    try generate(abstract_tree, outfile.writer());

    // use cc to compile .s file
    var cc = std.process.Child.init(&[_][]const u8{ "cc", "-o", "out", "out.s" }, allocator);
    _ = try cc.spawnAndWait();
}

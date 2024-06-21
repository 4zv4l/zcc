const builtin = @import("builtin");
const AST = @import("./ast.zig");
const Generator = @This();

fn generate_aarch64_osx(a: AST, writer: anytype) !void {
    for (a.program.function) |function| {
        try writer.print(
            \\.globl _{0s}
            \\_{0s}:
            \\
        , .{function.name});

        for (function.body) |statement| {
            switch (statement) {
                .@"return" => |ret| {
                    try writer.print(
                        \\  mov w0, #{0d}
                        \\  ret
                        \\
                    , .{ret.rc});
                },
                .call => |call| {
                    _ = call;
                    return error.NotImplemented;
                },
            }
        }
    }
}

/// Generate asm code from AST
pub fn generate(a: AST, writer: anytype) !void {
    try generate_aarch64_osx(a, writer);
}

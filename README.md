# zcc

Learning how to make a basic C compiler in Zig

## Why

I want to learn more about how to make a compiler.

I use [this website](https://norasandler.com/2017/11/29/Write-a-Compiler.html) to learn/help

## How to build

With `zig` using this command: `zig build-exe compiler.zig`

## How to use

`./compiler <file.c>`

The compiler can currently only compile a simple `return` kind of program and only for `aarch64`.

Something similar to this:

```c
int
main() {
    return 0;
}
```

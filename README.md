# sap

sap is a simple argument parser library for zig that uses a tuple of options to create a struct containing the value of the arguments.

## How to add the library

1. Run in the terminal:
```sh
zig fetch --save git+https://github.com/Reokodoku/sap
```
2. Add in your `build.zig`:
```zig
const sap = b.dependency("sap", .{});
exe.root_module.addImport("sap", sap.module("sap"));
```

## How to use

Call the `parseArgs` function, giving as the first argument a tuple of options and as the second argument an allocator.
It is recommended to use a `std.heap.ArenaAllocator` because the iterator will not be cleaned.

**Note**: you cannot create options named `executable_name` and `positionals`. These names are reserved.

For more information, see the source code or documentation (`zig build docs`).

### Examples

Minimal example:
```zig
const sap = @import("sap");

const args = try sap.parseArgs(.{
    sap.createOption([]const u8, "hello", 'h', "world"),
}, allocator);
defer args.positionals.deinit();

std.debug.print("Executable name: {s}\n", .{args.executable_name});
std.debug.print("Positionals:\n", .{});
for (args.positionals.items) |str|
    std.debug.print("  {s}\n", .{str});

std.debug.print("`hello`|`h` arg: {s}\n", .{args.hello});
```

You can find more examples in the `examples/` folder.

## Features

* short arguments
* long arguments
* pass values after an equal (`--foo=bar`) or a space (`--foo bar`)
* options can be specified multiple times
* options that call a function
* supported types:
    * booleans
    * strings
    * ints (signed and unsigned)
    * floats
    * enums
    * and all optional variants of the above (`?bool`, `?[]const u8`, ...)

## Zig version

sap targets the master branch of zig.
There is a file called `zig_version` which specifies the latest version of zig in which sap compiles.
When the zig master branch breaks the compilation, a commit will be merged to:

- fix the compilation errors
- update the zig version in the `zig_version` file


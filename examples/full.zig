const std = @import("std");
const sap = @import("sap");

const OPTIONS = .{
    sap.flag(?bool, "foo", null, null),
    sap.flag([]const u8, "bar", 'b', "FOO"),
    sap.flag(?[]const u8, "hello", null, null),
    sap.flag([]const u8, "world", null, "sad"),
    sap.flag(bool, "loop", 'l', false),
    sap.flag(u8, "port", 'p', 255),
    sap.flag(f64, "float", 'f', 434.0412),
    sap.flag(enum { zig, language }, "enum", 'e', .zig),
    sap.actionFlag("help", null, &helpFn),
};

fn helpFn(_args: *anyopaque) noreturn {
    const args: *sap.ParsedOptions(OPTIONS) = @ptrCast(@alignCast(_args));

    std.debug.print(
        \\full.zig - an example
        \\`enum` = {s}
        \\
    , .{@tagName(args.*.@"enum")});

    std.process.exit(0);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("MEMORY LEAK DETECTED!");

    var arg_parser = sap.Parser(OPTIONS).init(gpa.allocator());
    defer arg_parser.deinit();

    const args = try arg_parser.parseArgs();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Full struct: {any}\n\n", .{args});

    try stdout.print("Executable name: {s}\n", .{args.executable_name});

    var positionals_iter = args.positionals.iterator();
    try stdout.writeAll("Positionals:\n");
    while (positionals_iter.next()) |str|
        try stdout.print("  {s}\n", .{str});

    try stdout.print("foo:   {any}\n", .{args.foo});
    try stdout.print("bar:   {s}\n", .{args.bar});
    try stdout.print("hello: {any}\n", .{args.hello});
    try stdout.print("world: {s}\n", .{args.world});
    try stdout.print("loop:  {any}\n", .{args.loop});
    try stdout.print("port:  {d}\n", .{args.port});
    try stdout.print("float: {d}\n", .{args.float});
    try stdout.print("enum:  {s}\n", .{@tagName(args.@"enum")});
}

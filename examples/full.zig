const std = @import("std");
const sap = @import("sap");

fn helpFn() noreturn {
    std.debug.print("full.zig - an example\n", .{});

    std.process.exit(0);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("MEMORY LEAK DETECTED!");

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var args = try sap.parseArgs(.{
        sap.createOption(?bool, "foo", null, null),
        sap.createOption([]const u8, "bar", 'b', "FOO"),
        sap.createOption(?[]const u8, "hello", null, null),
        sap.createOption([]const u8, "world", null, "sad"),
        sap.createOption(bool, "loop", 'l', false),
        sap.createOption(u8, "port", 'p', 255),
        sap.createOption(f64, "float", 'f', 434.0412),
        sap.createOption(enum { zig, language }, "enum", 'e', .zig),
        sap.createActionOption("help", null, &helpFn),
    }, arena.allocator());
    defer args.positionals.deinit();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("Full struct: {any}\n\n", .{args});

    try stdout.print("Executable name: {s}\n", .{args.executable_name});

    try stdout.writeAll("Positionals:\n");
    for (args.positionals.items) |str|
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
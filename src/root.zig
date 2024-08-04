const options = @import("options.zig");
const parser = @import("parser.zig");

pub const ParsedOptions = parser.ParsedOptions;
pub const Parser = parser.Parser;
pub const ArgIterator = parser.ArgIterator;

pub const createOption = options.createOption;
pub const createActionOption = options.createActionOption;

// -- TESTS --
const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqualStrings = testing.expectEqualStrings;

const OPTIONS = .{
    createOption(?bool, "foo", null, null),
    createOption([]const u8, "bar", 'b', "FOO"),
    createOption(?[]const u8, "hello", null, null),
    createOption([]const u8, "world", null, "sad"),
    createOption(u8, "port", null, 2),
    createOption(i8, "int", null, 0),
    createOption(f32, "float", null, 3.0),
    createOption(bool, "loop", 'l', false),
    createOption(?enum { hello, world }, "enum", 'e', null),
    createActionOption("help", null, &testHelpFn),
};

var testHelpInvoked = false;
fn testHelpFn(_args: *anyopaque) void {
    const args: *ParsedOptions(OPTIONS) = @ptrCast(@alignCast(_args));

    expect(args.*.foo == true) catch @panic("TEST FAILED");

    testHelpInvoked = true;
}

test "generic" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(gpa.deinit() == .ok) catch @panic("TEST FAILED");

    var array_values = [_][:0]const u8{
        "./test",
        "--foo",
        "--bar",
        "123",
        "--hello=world=hello",
        "-l=true",
        "--help",
        "linux",
        "btw",
        "--port=32",
        "--int=-55",
        "--float=6.23",
        "-e=hello",
        "-e=world",
    };

    var arg_parser = Parser(OPTIONS).initWithArray(gpa.allocator(), &array_values);
    defer arg_parser.deinit();

    var args = try arg_parser.parseArgs();

    try expectEqualStrings(args.executable_name, "./test");
    try expect(args.positionals.items.len == 2);
    try expectEqualStrings(args.positionals.pop(), "btw");
    try expectEqualStrings(args.positionals.pop(), "linux");
    try expect(args.positionals.popOrNull() == null);

    try expect(args.foo == true);
    try expectEqualStrings(args.bar, "123");
    try expectEqualStrings(args.hello.?, "world=hello");
    try expectEqualStrings(args.world, "sad");
    try expect(args.port == 32);
    try expect(args.int == -55);
    try expect(args.float == 6.23);
    try expect(args.@"enum".? == .world);
    try expect(args.loop == true);
    try expect(testHelpInvoked == true);
}

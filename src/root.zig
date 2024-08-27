const flags = @import("flags.zig");
const parser = @import("parser.zig");

pub const ParsedOptions = parser.ParsedOptions;
pub const Parser = parser.Parser;
pub const ArgIterator = parser.ArgIterator;
pub const Positionals = @import("Positionals.zig");

pub const flag = flags.flag;
pub const actionFlag = flags.actionFlag;

// -- TESTS --
const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqualStrings = testing.expectEqualStrings;

const OPTIONS = .{
    flag(?bool, "foo", null, null),
    flag([]const u8, "bar", 'b', "FOO"),
    flag(?[]const u8, "hello", null, null),
    flag([]const u8, "world", null, "sad"),
    flag(u8, "port", null, 2),
    flag(i8, "int", null, 0),
    flag(f32, "float", null, 3.0),
    flag(bool, "loop", 'l', false),
    flag(?enum { hello, world }, "enum", 'e', null),
    actionFlag("help", null, &testHelpFn),
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
    try expect(args.positionals.array_list.items.len == 2);

    var positionals_iter = args.positionals.iterator();

    try expectEqualStrings(positionals_iter.first(), "linux");
    try expectEqualStrings(positionals_iter.next().?, "btw");
    try expect(positionals_iter.next() == null);

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

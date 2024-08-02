const std = @import("std");
const eql = std.mem.eql;
const Type = std.builtin.Type;

const RESERVED_FIELDS = 2;
fn ParsedOptions(comptime options: anytype) type {
    const OptionsType = @TypeOf(options);
    const options_type_info = @typeInfo(OptionsType);

    if (options_type_info != .Struct or !options_type_info.Struct.is_tuple)
        @compileError("Expected tuple, found " ++ @typeName(OptionsType));

    var i: usize = RESERVED_FIELDS;
    var fields: [options.len + RESERVED_FIELDS]Type.StructField = undefined;
    fields[0] = .{
        .name = "executable_name",
        .type = []const u8,
        .default_value = null,
        .is_comptime = false,
        .alignment = @alignOf([]const u8),
    };
    fields[1] = .{
        .name = "positionals",
        .type = std.ArrayList([]const u8),
        .default_value = null,
        .is_comptime = false,
        .alignment = @alignOf(std.ArrayList([]const u8)),
    };

    for (options) |option| {
        if (@hasField(@TypeOf(option), "func")) {
            const FieldType = @TypeOf(option.func);

            fields[i] = .{
                .name = option.name ++ "",
                .type = FieldType,
                .default_value = @ptrCast(&option.func),
                .is_comptime = false,
                .alignment = @alignOf(FieldType),
            };
        } else {
            const FieldType = @TypeOf(option.default_value);

            fields[i] = .{
                .name = option.name ++ "",
                .type = FieldType,
                .default_value = @ptrCast(&option.default_value),
                .is_comptime = false,
                .alignment = @alignOf(FieldType),
            };
        }
        i += 1;
    }

    return @Type(.{ .Struct = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

/// `options` must not have options named `executable_name` and `positionals`. These names are reserved.
/// You must call `positionals.deinit()` to clean up allocated resources.
/// This function doesn't call `deinit()` of `iter`.
/// Also, it is recommended to use a `std.heap.ArenaAllocator` (unless you are only targetting POSIX
/// platforms).
pub fn parseArgs(comptime options: anytype, allocator: std.mem.Allocator) !ParsedOptions(options) {
    var argsIter = try std.process.argsWithAllocator(allocator);

    return parseArgsWithIter(options, allocator, &argsIter);
}

/// `options` must not have options named `executable_name` and `positionals`. These names are reserved.
/// You must call `positionals.deinit()` to clean up allocated resources.
/// This function doesn't call `deinit()` of `iter`.
pub fn parseArgsWithIter(comptime options: anytype, allocator: std.mem.Allocator, iter: anytype) !ParsedOptions(options) {
    var positionals = std.ArrayList([]const u8).init(allocator);

    var parsed: ParsedOptions(options) = .{
        .executable_name = iter.next().?,
        .positionals = undefined,
    };

    while (iter.next()) |arg| {
        if (arg[0] != '-')
            try positionals.append(arg);

        if (arg[1] == '-') {
            var split = std.mem.splitScalar(u8, arg[2..], '=');
            inline for (@typeInfo(@TypeOf(parsed)).Struct.fields[RESERVED_FIELDS..]) |field| {
                if (eql(u8, field.name, split.first()))
                    argSetter(&parsed, field, split.rest(), iter);
                split.reset();
            }
        } else {
            var split = std.mem.splitScalar(u8, arg[1..], '=');
            inline for (options) |option| {
                split.reset();
                if (option.short_name == split.first()[0]) {
                    inline for (@typeInfo(@TypeOf(parsed)).Struct.fields[RESERVED_FIELDS..]) |field| {
                        if (eql(u8, field.name, option.name))
                            argSetter(&parsed, field, split.rest(), iter);
                    }
                }
            }
        }
    }

    parsed.positionals = positionals;

    return parsed;
}

fn argSetter(parsed: anytype, field: Type.StructField, equal_str: []const u8, iter: anytype) void {
    // Check if the option is an action option
    if (@typeInfo(field.type) == .Pointer and @typeInfo(field.type).Pointer.child == fn () void)
        return @field(parsed, field.name)();

    if (!eql(u8, equal_str, "")) {
        @field(parsed, field.name) = getValue(field.type, equal_str);
    } else {
        if (field.type == ?bool or field.type == bool)
            @field(parsed, field.name) = true
        else
            @field(parsed, field.name) = getValue(field.type, iter.next());
    }
}

fn getValue(T: type, val: ?[]const u8) T {
    switch (T) {
        ?[]const u8, []const u8 => {
            if (val) |v|
                return v
            else
                @panic("String options require a string");
        },
        ?bool, bool => {
            // Here `bool`s are called only when we pass a non-null string,
            // so we can use .? without any problem.
            return if (eql(u8, "true", val.?))
                true
            else if (eql(u8, "false", val.?))
                false
            else
                @panic("Bool options only accept `true` or `false`");
        },
        else => {},
    }

    return if (val) |v| switch (@typeInfo(T)) {
        .Optional => |i| getValue(i.child, val),
        .Int => std.fmt.parseInt(T, v, 0) catch @panic("Error when parsing int option"),
        .Float => std.fmt.parseFloat(T, v) catch @panic("Error when parsing float option"),
        .Enum => std.meta.stringToEnum(T, v) orelse @panic("Error when parsing enum option: variant doesn't exist"),
        else => @compileError(@typeName(T) ++ " is not supported"),
    } else {
        @panic(@tagName(@typeInfo(T)) ++ " options require a string");
    };
}

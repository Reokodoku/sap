const std = @import("std");
const eql = std.mem.eql;
const Type = std.builtin.Type;

const RESERVED_FIELDS = 2;
pub fn ParsedOptions(comptime options: anytype) type {
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
/// You must call `deinit()` to clean up allocated resources.
pub fn Parser(comptime options: anytype) type {
    return struct {
        const Self = @This();

        parsed: ParsedOptions(options),
        allocator: std.mem.Allocator,
        args: union(enum) {
            std: *std.process.ArgIterator,
            custom: *struct {
                values: [][:0]const u8,
                index: usize = 0,
            },

            fn next(self: *@This()) ?[:0]const u8 {
                switch (self.*) {
                    .std => |iter| return iter.next(),
                    .custom => |iter| {
                        if (iter.index >= iter.values.len)
                            return null;

                        const val = iter.values[iter.index];
                        iter.index += 1;

                        return val;
                    },
                }
            }

            fn deinit(self: *@This()) void {
                switch (self.*) {
                    .std => |iter| iter.deinit(),
                    .custom => {},
                }
            }
        },

        action_to_call: ?*const fn (*anyopaque) void = null,

        pub fn init(allocator: std.mem.Allocator) Self {
            var iter = std.process.argsWithAllocator(allocator) catch @panic("OOM");

            return .{
                .parsed = undefined,
                .allocator = allocator,
                .args = .{ .std = &iter },
            };
        }

        pub fn initWithArray(allocator: std.mem.Allocator, args: [][:0]const u8) Self {
            return .{
                .parsed = undefined,
                .allocator = allocator,
                .args = .{ .custom = @constCast(&.{ .values = args }) },
            };
        }

        pub fn deinit(self: *Self) void {
            self.parsed.positionals.deinit();
            self.args.deinit();
        }

        pub fn parseArgs(self: *Self) !ParsedOptions(options) {
            var positionals = std.ArrayList([]const u8).init(self.allocator);

            self.parsed = .{
                .executable_name = self.args.next().?,
                .positionals = undefined,
            };

            while (self.args.next()) |arg| {
                if (arg[0] != '-')
                    try positionals.append(arg);

                if (arg[1] == '-') {
                    var split = std.mem.splitScalar(u8, arg[2..], '=');
                    inline for (@typeInfo(@TypeOf(self.parsed)).Struct.fields[RESERVED_FIELDS..]) |field| {
                        if (eql(u8, field.name, split.first()))
                            self.argSetter(field, split.rest());
                        split.reset();
                    }
                } else {
                    var split = std.mem.splitScalar(u8, arg[1..], '=');
                    inline for (options) |option| {
                        split.reset();
                        if (option.short_name == split.first()[0]) {
                            inline for (@typeInfo(@TypeOf(self.parsed)).Struct.fields[RESERVED_FIELDS..]) |field| {
                                if (eql(u8, field.name, option.name))
                                    self.argSetter(field, split.rest());
                            }
                        }
                    }
                }
            }

            self.parsed.positionals = positionals;

            if (self.action_to_call) |func|
                func(@ptrCast(&self.parsed));

            return self.parsed;
        }

        fn argSetter(self: *Self, field: Type.StructField, equal_str: []const u8) void {
            // Check if the option is an action option
            if (@typeInfo(field.type) == .Pointer and @typeInfo(field.type).Pointer.child == fn (*anyopaque) void) {
                self.action_to_call = @field(self.parsed, field.name);
                return;
            }

            if (!eql(u8, equal_str, "")) {
                @field(self.parsed, field.name) = getValue(field.type, equal_str);
            } else {
                if (field.type == ?bool or field.type == bool)
                    @field(self.parsed, field.name) = true
                else
                    @field(self.parsed, field.name) = getValue(field.type, self.args.next());
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
    };
}

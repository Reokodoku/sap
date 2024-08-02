pub fn createOption(comptime T: type, comptime name: []const u8, comptime short_name: ?u8, comptime default_value: T) struct {
    name: []const u8,
    short_name: ?u8,
    default_value: T,
} {
    return .{
        .name = name,
        .short_name = short_name,
        .default_value = default_value,
    };
}

/// When this option is specified, the parser calls the provided function.
pub fn createActionOption(comptime name: []const u8, comptime short_name: ?u8, func: *const fn () void) struct {
    name: []const u8,
    short_name: ?u8,
    func: *const fn () void,
} {
    return .{
        .name = name,
        .short_name = short_name,
        .func = func,
    };
}
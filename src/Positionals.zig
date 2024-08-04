const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

pub const Iterator = struct {
    items: [][]const u8,
    index: usize,

    pub fn init(items: [][]const u8) Iterator {
        return .{
            .index = 0,
            .items = items,
        };
    }

    pub fn first(self: *Iterator) []const u8 {
        assert(self.index == 0);
        return self.next().?;
    }

    pub fn next(self: *Iterator) ?[]const u8 {
        if (self.index >= self.items.len)
            return null;

        const val = self.items[self.index];
        self.index += 1;

        return val;
    }

    pub fn peek(self: *Iterator) ?[]const u8 {
        if (self.index >= self.items.len)
            return null;

        return self.items[self.index];
    }

    pub fn reset(self: *Iterator) void {
        self.index = 0;
    }
};

const Self = @This();

array_list: std.ArrayList([]const u8),

pub fn init(allocator: Allocator) Self {
    return .{
        .array_list = std.ArrayList([]const u8).init(allocator),
    };
}

pub fn deinit(self: Self) void {
    self.array_list.deinit();
}

pub fn append(self: *Self, string: []const u8) !void {
    try self.array_list.append(string);
}

pub fn iterator(self: Self) Iterator {
    return Iterator.init(self.array_list.items);
}

const std = @import("std");
const Allocator = std.mem.Allocator;

fn Stack(comptime T: type) type {
    return struct {
        items: []T,
        capacity: usize,
        length: usize,
        allocator: Allocator,
        const Self = @This();

        pub fn init(allocator: Allocator, capacity: usize) !Self {
            var buff = try allocator.alloc(T, capacity);
            return .{ .allocator = allocator, .items = buff[0..], .capacity = capacity, .length = 0 };
        }

        pub fn push(self: *Self, element: T) !void {
            if ((self.length + 1) > self.capacity) {
                var new_buffer = try self.allocator.alloc(T, self.capacity * 2);
                @memcpy(new_buffer[0..self.capacity], self.items);
                self.allocator.free(self.items);
                self.items = new_buffer;
                self.capacity = self.capacity * 2;
            }
            self.items[self.length] = element;
            self.length += 1;
        }

        pub fn pop(self: *Self) void {
            if (self.length == 0) return;
            self.items[self.length - 1] = undefined;
            self.length -= 1;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }
    };
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;

const StackFrame = @import("vm.zig").StackFrame;

pub fn Stack(comptime T: type) type {
    return struct {
        items: []T,
        capacity: usize,
        length: usize,
        allocator: Allocator,
        const Self = @This();

        pub fn init(allocator: Allocator, capacity: usize) !*Self {
            var stack = try allocator.create(Stack(T));
            var buff = try allocator.alloc(T, capacity);
            stack.allocator = allocator;
            stack.items = buff[0..];
            stack.capacity = capacity;
            stack.length = 0;
            return stack;
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
            self.allocator.destroy(self);
        }
    };
}

test "Check stack data structure" {
    const allocator = std.testing.allocator;
    var stack = try Stack(u32).init(allocator, 8);
    defer stack.deinit();
    try expect(stack.capacity == 8);
    try expect(stack.length == 0);
    try stack.push(12);
    try expect(stack.length == 1);
    try expect(stack.items[0] == 12);
    stack.pop();
    try expect(stack.length == 0);
    stack.pop();
    stack.pop();
    stack.pop();
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Stack = @import("stack.zig").Stack;
const expect = std.testing.expect;

fn VirtualMachine(comptime T: type) type {
    return struct {
        frames: *Stack(*StackFrame(T)),
        objects: *Stack(T),
        allocator: Allocator,
        const Self = @This();

        fn init(allocator: Allocator) !*Self {
            var vm = try allocator.create(VirtualMachine(T));
            const frames = try Stack(*StackFrame(T)).init(allocator, 8);
            const objects = try Stack(T).init(allocator, 8);
            vm.allocator = allocator;
            vm.objects = objects;
            vm.frames = frames;
            return vm;
        }

        fn frame_push(self: *Self, frame: StackFrame(T)) !void {
            try self.frames.push(frame);
        }

        fn deinit(self: *Self) void {
            self.objects.deinit();
            self.frames.deinit();
            self.allocator.destroy(self);
        }
    };
}

fn StackFrame(comptime T: type) type {
    return struct {
        allocator: Allocator,
        references: *Stack(T),
        const Self = @This();

        fn init(allocator: Allocator, vm: *VirtualMachine(T)) !*Self {
            const frame = try allocator.create(StackFrame(T));
            frame.references = try Stack(T).init(allocator, 8);
            frame.allocator = allocator;
            try vm.frames.push(frame);
            return frame;
        }

        fn deinit(self: *Self) void {
            self.references.deinit();
            self.allocator.destroy(self);
        }
    };
}

test "Testing VM" {
    const allocator = std.testing.allocator;
    const vm = try VirtualMachine(u32).init(allocator);
    vm.deinit();
}

test "Init VM" {
    const allocator = std.testing.allocator;
    const vm = try VirtualMachine(u32).init(allocator);
    defer vm.deinit();
    const sf = try StackFrame(u32).init(allocator, vm);
    defer sf.deinit();

    try expect(vm.frames.length==1);
}

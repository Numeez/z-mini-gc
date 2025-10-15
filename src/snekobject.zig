const std = @import("std");
const expect = std.testing.expect;

const SnekObjectKind = enum {
    INTEGER,
    FLOAT,
    STRING,
    VECTOR3,
    ARRAY,
};

const SnekObjectData = union {
    v_int: i64,
    v_float: f64,
    v_string: []const u8,
    v_vector3: SnekVector,
    v_array: SnekArray,
};

const SnekObject = struct {
    referenceCount: usize,
    kind: SnekObjectKind,
    data: SnekObjectData,

    fn new(allocator: std.mem.Allocator) !*SnekObject {
        var obj = try allocator.create(SnekObject);
        obj.referenceCount = 1;
        return obj;
    }
    fn refCountInc(self: ?*SnekObject) void {
        self.?.referenceCount += 1;
    }
    fn decCountInc(self: ?*SnekObject, allocator: std.mem.Allocator) void {
        if (self == null) {
            return;
        }
        self.?.referenceCount -= 1;
        if (self.?.referenceCount == 0) {
            SnekObject.refCountFree(self.?, allocator);
        }
    }
    fn refCountFree(object: *SnekObject, allocator: std.mem.Allocator) void {
        switch (object.kind) {
            SnekObjectKind.INTEGER, SnekObjectKind.FLOAT => {
                allocator.destroy(object);
            },
            SnekObjectKind.STRING => {
                allocator.free(object.data.v_string);
                allocator.destroy(object);
            },
            SnekObjectKind.VECTOR3 => {
                SnekObject.decCountInc(object.data.v_vector3.x, allocator);
                SnekObject.decCountInc(object.data.v_vector3.y, allocator);
                SnekObject.decCountInc(object.data.v_vector3.z, allocator);
                allocator.destroy(object);
            },
            SnekObjectKind.ARRAY => {
                for (object.data.v_array.elements) |element| {
                    SnekObject.decCountInc(element, allocator);
                }
                allocator.destroy(object);
            },
        }
    }
    fn newSnekInteger(allocator: std.mem.Allocator, value: i64) ?*SnekObject {
        var obj = SnekObject.new(allocator) catch {
            return null;
        };
        obj.kind = SnekObjectKind.INTEGER;
        obj.data = SnekObjectData{ .v_int = value };
        return obj;
    }
    fn newSnekFloat(allocator: std.mem.Allocator, value: f64) ?*SnekObject {
        var obj = SnekObject.new(allocator) catch {
            return null;
        };
        obj.kind = SnekObjectKind.FLOAT;
        obj.data = SnekObjectData{ .v_float = value };
        return obj;
    }
    fn newSnekString(allocator: std.mem.Allocator, value: []const u8) ?*SnekObject {
        var obj = SnekObject.new(allocator) catch {
            return null;
        };
        obj.kind = SnekObjectKind.STRING;
        const string_value = allocator.dupe(u8, value) catch {
            return null;
        };
        obj.data = SnekObjectData{ .v_string = string_value };
        return obj;
    }
    fn newSnekVector3(allocator: std.mem.Allocator, x: ?*SnekObject, y: ?*SnekObject, z: ?*SnekObject) ?*SnekObject {
        var obj = SnekObject.new(allocator) catch {
            return null;
        };
        obj.kind = SnekObjectKind.VECTOR3;
        SnekObject.refCountInc(x);
        SnekObject.refCountInc(y);
        SnekObject.refCountInc(z);
        const value = SnekVector{ .x = x, .y = y, .z = z };
        obj.data = SnekObjectData{ .v_vector3 = value };
        return obj;
    }
    fn newSnekArray(allocator: std.mem.Allocator, size: usize) ?*SnekObject {
        var obj = SnekObject.new(allocator) catch {
            return null;
        };
        errdefer allocator.destroy(obj);
        const snekObjectData = allocator.alloc(?*SnekObject, size) catch {
            return null;
        };
        errdefer allocator.free(snekObjectData);
        obj.kind = SnekObjectKind.ARRAY;
        const value = SnekArray{ .size = size, .elements = snekObjectData };
        obj.data = SnekObjectData{ .v_array = value };
        return obj;
    }
};

const SnekVector = struct {
    x: ?*SnekObject,
    y: ?*SnekObject,
    z: ?*SnekObject,
};
const SnekArray = struct {
    size: usize,
    elements: []?*SnekObject,

    fn set(self: *SnekArray, index: usize, value: ?*SnekObject, allocator: std.mem.Allocator) bool {
        if (value == null) {
            return false;
        }
        if (self.size - 1 < index) {
            return false;
        }
        value.?.referenceCount += 1;
        if (self.elements[index] != null) {
            const old = self.elements[index];
            SnekObject.decCountInc(old, allocator);
            self.elements[index] = value.?;
        } else {
            self.elements[index] = value.?;
        }
        return true;
    }
    fn get(self: *SnekArray, index: usize) ?*SnekObject {
        if (self.size - 1 < index) {
            return null;
        }
        return self.elements[index];
    }
};

fn length(value: ?*SnekObject) usize {
    if (value == null) {
        return 0;
    }
    switch (value.?.kind) {
        SnekObjectKind.INTEGER, SnekObjectKind.FLOAT => return 1,
        SnekObjectKind.VECTOR3 => return 3,
        SnekObjectKind.STRING => return value.?.data.v_string.len,
        SnekObjectKind.ARRAY => return value.?.data.v_array.size,
    }
}
fn add(allocator: std.mem.Allocator, a: ?*SnekObject, b: ?*SnekObject) ?*SnekObject {
    switch (a.?.kind) {
        SnekObjectKind.INTEGER => {
            if (b.?.kind == SnekObjectKind.INTEGER) {
                return SnekObject.newSnekInteger(allocator, a.?.data.v_int + b.?.data.v_int);
            } else if (b.?.kind == SnekObjectKind.FLOAT) {
                return SnekObject.newSnekFloat(allocator, @as(f64, @floatFromInt(a.?.data.v_int)) + b.?.data.v_float);
            } else {
                return null;
            }
        },
        SnekObjectKind.FLOAT => {
            if (b.?.kind == SnekObjectKind.FLOAT) {
                return SnekObject.newSnekFloat(allocator, a.?.data.v_float + b.?.data.v_float);
            } else if (b.?.kind == SnekObjectKind.INTEGER) {
                return SnekObject.newSnekFloat(allocator, a.?.data.v_float + @as(f64, @floatFromInt(b.?.data.v_int)));
            } else {
                return null;
            }
        },
        SnekObjectKind.STRING => {
            if (b.?.kind == SnekObjectKind.STRING) {
                const parts = [_][]const u8{ a.?.data.v_string, b.?.data.v_string };
                const joined = std.mem.concat(allocator, u8, &parts) catch {
                    return null;
                };
                defer allocator.free(joined);
                return SnekObject.newSnekString(allocator, joined);
            } else {
                return null;
            }
        },
        SnekObjectKind.VECTOR3 => {
            if (b.?.kind == SnekObjectKind.VECTOR3) {
                return SnekObject.newSnekVector3(allocator, add(allocator, a.?.data.v_vector3.x, b.?.data.v_vector3.x), add(allocator, a.?.data.v_vector3.y, b.?.data.v_vector3.y), add(allocator, a.?.data.v_vector3.z, b.?.data.v_vector3.z));
            } else {
                return null;
            }
        },
        SnekObjectKind.ARRAY => {
            if (b.?.kind == SnekObjectKind.ARRAY) {
                const lengthA = a.?.data.v_array.size;
                const lengthB = b.?.data.v_array.size;
                const size = lengthA + lengthB;
                const obj = SnekObject.newSnekArray(allocator, size);
                for (a.?.data.v_array.elements, 0..) |data, index| {
                    const result = obj.?.data.v_array.set(index, data,allocator);
                    if (result) {
                        return null;
                    }
                }
                for (b.?.data.v_array.elements, 0..) |data, index| {
                    const result = obj.?.data.v_array.set(a.?.data.v_array.size + index + index, data,allocator);
                    if (result) {
                        return null;
                    }
                }
                return obj;
            } else {
                return null;
            }
        },
    }
}
test "test integer object" {
    var allocator = std.testing.allocator;
    var obj = try allocator.create(SnekObject);
    defer allocator.destroy(obj);
    obj.kind = SnekObjectKind.INTEGER;
    obj.data = SnekObjectData{ .v_int = 0 };
    try expect(obj.kind == SnekObjectKind.INTEGER);
    try expect(obj.data.v_int == 0);
}

test "test integer zero" {
    const allocator = std.testing.allocator;
    const obj = SnekObject.newSnekInteger(allocator, 0);
    defer allocator.destroy(obj.?);
    try expect(obj.?.kind == SnekObjectKind.INTEGER);
    try expect(obj.?.data.v_int == 0);
}
test "test integer positive" {
    const allocator = std.testing.allocator;
    const obj = SnekObject.newSnekInteger(allocator, 17);
    defer allocator.destroy(obj.?);
    try expect(obj.?.kind == SnekObjectKind.INTEGER);
    try expect(obj.?.data.v_int == 17);
}
test "test integer negative" {
    const allocator = std.testing.allocator;
    const obj = SnekObject.newSnekInteger(allocator, -17);
    defer allocator.destroy(obj.?);
    try expect(obj.?.kind == SnekObjectKind.INTEGER);
    try expect(obj.?.data.v_int == -17);
}

test "test float zero" {
    const allocator = std.testing.allocator;
    const obj = SnekObject.newSnekFloat(allocator, 0.0);
    defer allocator.destroy(obj.?);
    try expect(obj.?.kind == SnekObjectKind.FLOAT);
    try expect(obj.?.data.v_float == 0.0);
}
test "test float positive" {
    const allocator = std.testing.allocator;
    const obj = SnekObject.newSnekFloat(allocator, 35.12);
    defer allocator.destroy(obj.?);
    try expect(obj.?.kind == SnekObjectKind.FLOAT);
    try expect(obj.?.data.v_float == 35.12);
}
test "test float negative" {
    const allocator = std.testing.allocator;
    const obj = SnekObject.newSnekFloat(allocator, -97.15);
    defer allocator.destroy(obj.?);
    try expect(obj.?.kind == SnekObjectKind.FLOAT);
    try expect(obj.?.data.v_float == -97.15);
}

test "test string allocation" {
    const value: []const u8 = "Hello this is test for strings in gc in Zig";
    const allocator = std.testing.allocator;
    const obj = SnekObject.newSnekString(allocator, value);
    defer allocator.destroy(obj.?);
    defer allocator.free(obj.?.data.v_string);
    try expect(obj.?.kind == SnekObjectKind.STRING);
    try expect(!(&obj.?.data.v_string == &value));
    try expect(std.mem.eql(u8, obj.?.data.v_string, value));
}

test "test vector object type" {
    const allocator = std.testing.allocator;
    const x = SnekObject.newSnekInteger(allocator, 1);
    defer allocator.destroy(x.?);
    const y = SnekObject.newSnekInteger(allocator, 2);
    defer allocator.destroy(y.?);
    const z = SnekObject.newSnekInteger(allocator, 3);
    defer allocator.destroy(z.?);
    const obj = SnekObject.newSnekVector3(allocator, x, y, z);
    defer allocator.destroy(obj.?);
    try expect(obj.?.data.v_vector3.x.? == x);
    try expect(obj.?.data.v_vector3.y.? == y);
    try expect(obj.?.data.v_vector3.z.? == z);
    try expect(obj.?.data.v_vector3.x.?.data.v_int == 1);
    try expect(obj.?.data.v_vector3.y.?.data.v_int == 2);
    try expect(obj.?.data.v_vector3.z.?.data.v_int == 3);
}

test "test array object" {
    const allocator = std.testing.allocator;
    const obj = SnekObject.newSnekArray(allocator, 2);
    defer allocator.destroy(obj.?);
    defer allocator.free(obj.?.data.v_array.elements);
    try expect(obj.?.data.v_array.size == 2);
    try expect(obj.?.kind == SnekObjectKind.ARRAY);
}

test "test array object set and get" {
    const allocator = std.testing.allocator;
    const obj = SnekObject.newSnekArray(allocator, 2);
    defer allocator.destroy(obj.?);
    defer allocator.free(obj.?.data.v_array.elements);
    const value1 = SnekObject.newSnekInteger(allocator, 25);
    defer allocator.destroy(value1.?);
    const value2 = SnekObject.newSnekInteger(allocator, 36);
    defer allocator.destroy(value2.?);
    try expect(obj.?.data.v_array.set(0, value1,allocator));
    try expect(obj.?.data.v_array.set(1, value2,allocator));

    try expect(obj.?.data.v_array.get(0).?.data.v_int == 25);
    try expect(obj.?.data.v_array.get(1).?.data.v_int == 36);

    try expect(!obj.?.data.v_array.set(15, value1,allocator));
    try expect(obj.?.data.v_array.get(13) == null);
}

test "test length function for our objects" {
    const allocator = std.testing.allocator;
    const obj_int = SnekObject.newSnekInteger(allocator, 12);
    defer allocator.destroy(obj_int.?);
    const obj_float = SnekObject.newSnekFloat(allocator, 35.6);
    defer allocator.destroy(obj_float.?);
    const obj_string = SnekObject.newSnekString(allocator, "hello");
    defer allocator.destroy(obj_string.?);
    defer allocator.free(obj_string.?.data.v_string);
    const x = SnekObject.newSnekInteger(allocator, 1);
    defer allocator.destroy(x.?);
    const y = SnekObject.newSnekInteger(allocator, 2);
    defer allocator.destroy(y.?);
    const z = SnekObject.newSnekInteger(allocator, 3);
    defer allocator.destroy(z.?);
    const obj_vector = SnekObject.newSnekVector3(allocator, x.?, y.?, z.?);
    defer allocator.destroy(obj_vector.?);
    const obj_array = SnekObject.newSnekArray(allocator, 2);
    defer allocator.destroy(obj_array.?);
    defer allocator.free(obj_array.?.data.v_array.elements);

    try expect(length(obj_int) == 1);
    try expect(length(obj_float) == 1);
    try expect(length(obj_string) == 5);
    try expect(length(obj_vector) == 3);
    try expect(length(obj_array) == 2);
}

test "test add for integer" {
    const allocator = std.testing.allocator;
    const val_1 = SnekObject.newSnekInteger(allocator, 34);
    defer allocator.destroy(val_1.?);
    const val_2 = SnekObject.newSnekInteger(allocator, 40);
    defer allocator.destroy(val_2.?);
    const result = add(allocator, val_1, val_2);
    defer allocator.destroy(result.?);
    const float_val_2 = SnekObject.newSnekFloat(allocator, 40.3);
    defer allocator.destroy(float_val_2.?);
    const float_result = add(allocator, val_1, float_val_2);
    defer allocator.destroy(float_result.?);
    try expect(result.?.kind == SnekObjectKind.INTEGER);
    try expect(result.?.data.v_int == 74);
    try expect(float_result.?.kind == SnekObjectKind.FLOAT);
    try expect(float_result.?.data.v_float == 74.3);
}

test "test add for float" {
    const allocator = std.testing.allocator;
    const val_1 = SnekObject.newSnekFloat(allocator, 34.3);
    defer allocator.destroy(val_1.?);
    const val_2 = SnekObject.newSnekFloat(allocator, 40.3);
    defer allocator.destroy(val_2.?);
    const result = add(allocator, val_1, val_2);
    defer allocator.destroy(result.?);
    const int_val_2 = SnekObject.newSnekInteger(allocator, 40);
    defer allocator.destroy(int_val_2.?);
    const float_result = add(allocator, val_1, int_val_2);
    defer allocator.destroy(float_result.?);
    try expect(result.?.kind == SnekObjectKind.FLOAT);
    try expect(result.?.data.v_float == 74.6);
    try expect(float_result.?.kind == SnekObjectKind.FLOAT);
    try expect(float_result.?.data.v_float == 74.3);
}

test "test add for string" {
    const allocator = std.testing.allocator;
    const val_1 = SnekObject.newSnekString(allocator, "Hello");
    defer allocator.destroy(val_1.?);
    defer allocator.free(val_1.?.data.v_string);
    const val_2 = SnekObject.newSnekString(allocator, " World");
    defer allocator.destroy(val_2.?);
    defer allocator.free(val_2.?.data.v_string);
    const result = add(allocator, val_1, val_2);
    defer allocator.destroy(result.?);
    defer allocator.free(result.?.data.v_string);
    try expect(result.?.kind == SnekObjectKind.STRING);
}

test "test add for vector" {
    const allocator = std.testing.allocator;
    const x = SnekObject.newSnekInteger(allocator, 1);
    defer allocator.destroy(x.?);
    const y = SnekObject.newSnekInteger(allocator, 2);
    defer allocator.destroy(y.?);
    const z = SnekObject.newSnekInteger(allocator, 3);
    defer allocator.destroy(z.?);
    const obj = SnekObject.newSnekVector3(allocator, x, y, z);
    defer allocator.destroy(obj.?);
    const x2 = SnekObject.newSnekInteger(allocator, 1);
    defer allocator.destroy(x2.?);
    const y2 = SnekObject.newSnekInteger(allocator, 2);
    defer allocator.destroy(y2.?);
    const z2 = SnekObject.newSnekInteger(allocator, 3);
    defer allocator.destroy(z2.?);
    const obj2 = SnekObject.newSnekVector3(allocator, x2, y2, z2);
    defer allocator.destroy(obj2.?);
    const result = add(allocator, obj, obj2);
    defer allocator.destroy(result.?);
    defer allocator.destroy(result.?.data.v_vector3.x.?);
    defer allocator.destroy(result.?.data.v_vector3.y.?);
    defer allocator.destroy(result.?.data.v_vector3.z.?);

    try expect(result.?.data.v_vector3.x.?.data.v_int == 2);
    try expect(result.?.data.v_vector3.y.?.data.v_int == 4);
    try expect(result.?.data.v_vector3.z.?.data.v_int == 6);
}

test "testing the reference count of the object" {
    const allocator = std.testing.allocator;
    const x = SnekObject.newSnekInteger(allocator, 1);
    defer allocator.destroy(x.?);
    try expect(x.?.referenceCount == 1);
    SnekObject.refCountInc(x);
    SnekObject.refCountInc(x);
    SnekObject.refCountInc(x);
    try expect(x.?.referenceCount == 4);
}

test "testing decrement ref count" {
    const allocator = std.testing.allocator;
    const x = SnekObject.newSnekInteger(allocator, 1);
    try expect(x.?.referenceCount == 1);
    SnekObject.refCountInc(x);
    SnekObject.decCountInc(x, allocator);
    try expect(x.?.referenceCount == 1);
    SnekObject.decCountInc(x, allocator);
}

test "freeing of vector" {
    const allocator = std.testing.allocator;
    const x = SnekObject.newSnekInteger(allocator, 1);
    const y = SnekObject.newSnekInteger(allocator, 2);
    const z = SnekObject.newSnekInteger(allocator, 3);
    const result = SnekObject.newSnekVector3(allocator, x, y, z);
    try expect(x.?.referenceCount == 2);
    try expect(y.?.referenceCount == 2);
    try expect(z.?.referenceCount == 2);
    SnekObject.decCountInc(x, allocator);
    try expect(x.?.referenceCount == 1);
    SnekObject.decCountInc(result, allocator);
    try expect(y.?.referenceCount == 1);
    try expect(z.?.referenceCount == 1);
    SnekObject.decCountInc(y, allocator);
    SnekObject.decCountInc(z, allocator);
}

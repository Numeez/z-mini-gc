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
    kind: SnekObjectKind,
    data: SnekObjectData,
    fn newSnekInteger(allocator: std.mem.Allocator, value: i64) !*SnekObject {
        var obj = try allocator.create(SnekObject);
        obj.kind = SnekObjectKind.INTEGER;
        obj.data = SnekObjectData{ .v_int = value };
        return obj;
    }
    fn newSnekFloat(allocator: std.mem.Allocator, value: f64) !*SnekObject {
        var obj = try allocator.create(SnekObject);
        obj.kind = SnekObjectKind.FLOAT;
        obj.data = SnekObjectData{ .v_float = value };
        return obj;
    }
    fn newSnekString(allocator: std.mem.Allocator, value: []const u8) !*SnekObject {
        var obj = try allocator.create(SnekObject);
        obj.kind = SnekObjectKind.STRING;
        obj.data = SnekObjectData{ .v_string = value };
        return obj;
    }
    fn newSnekVector3(allocator: std.mem.Allocator, x: *SnekObject, y: *SnekObject, z: *SnekObject) !*SnekObject {
        var obj = try allocator.create(SnekObject);
        obj.kind = SnekObjectKind.VECTOR3;
        const value = SnekVector{ .x = x, .y = y, .z = z };
        obj.data = SnekObjectData{ .v_vector3 = value };
        return obj;
    }
    fn newSnekArray(allocator: std.mem.Allocator, size: usize) !*SnekObject {
        var obj = try allocator.create(SnekObject);
        errdefer allocator.destroy(obj);
        const snekObjectData = try allocator.alloc(*SnekObject, size);
        errdefer allocator.free(snekObjectData);
        obj.kind = SnekObjectKind.ARRAY;
        const value = SnekArray{ .size = size, .elements = snekObjectData };
        obj.data = SnekObjectData{ .v_array = value };
        return obj;
    }
};

const SnekVector = struct {
    x: *SnekObject,
    y: *SnekObject,
    z: *SnekObject,
};
const SnekArray = struct {
    size: usize,
    elements: []*SnekObject,

    fn set(self: *SnekArray, index: usize, value: *SnekObject) bool {
        if (self.size - 1 < index) {
            return false;
        }
        self.elements[index] = value;
        return true;
    }
    fn get(self: *SnekArray, index: usize) ?*SnekObject {
        if (self.size - 1 < index) {
            return null;
        }
        return self.elements[index];
    }
};

fn length(value: *SnekObject) usize {
    switch (value.kind) {
        SnekObjectKind.INTEGER, SnekObjectKind.FLOAT => return 1,
        SnekObjectKind.VECTOR3 => return 3,
        SnekObjectKind.STRING => return value.data.v_string.len,
        SnekObjectKind.ARRAY => return value.data.v_array.size,
    }
}
fn add(allocator: std.mem.Allocator, a: *SnekObject, b: *SnekObject) !*SnekObject {
    switch (a.kind) {
        SnekObjectKind.INTEGER => {
            if (b.kind == SnekObjectKind.INTEGER) {
                return try SnekObject.newSnekInteger(allocator, a.data.v_int + b.data.v_int);
            } else if (b.kind == SnekObjectKind.FLOAT) {
                return try SnekObject.newSnekFloat(allocator, @as(f64, @floatFromInt(a.data.v_int)) + b.data.v_float);
            } else {
                return error.InvalidTypeForAddition;
            }
        },
        SnekObjectKind.FLOAT => {
            if (b.kind == SnekObjectKind.FLOAT) {
                return try SnekObject.newSnekFloat(allocator, a.data.v_float + b.data.v_float);
            } else if (b.kind == SnekObjectKind.INTEGER) {
                return try SnekObject.newSnekFloat(allocator, a.data.v_float + @as(f64, @floatFromInt(b.data.v_int)));
            } else {
                return error.InvalidTypeForAddition;
            }
        },
        SnekObjectKind.STRING => {
            if (b.kind == SnekObjectKind.STRING) {
                const parts = [_][]const u8{ a.data.v_string, b.data.v_string };
                const joined = try std.mem.concat(allocator, u8, &parts);
                defer allocator.free(joined);
                return try SnekObject.newSnekString(allocator, try allocator.dupe(u8, joined));
            } else {
                return error.InvalidTypeForAddition;
            }
        },
        SnekObjectKind.VECTOR3 => {
            if (b.kind == SnekObjectKind.VECTOR3) {
                return try SnekObject.newSnekVector3(allocator, try add(allocator, a.data.v_vector3.x, b.data.v_vector3.x), try add(allocator, a.data.v_vector3.y, b.data.v_vector3.y), try add(allocator, a.data.v_vector3.z, b.data.v_vector3.z));
            } else {
                return error.InvalidTypeForAddition;
            }
        },
        SnekObjectKind.ARRAY => {
            if (b.kind == SnekObjectKind.ARRAY) {
                const lengthA = a.data.v_array.size;
                const lengthB = b.data.v_array.size;
                const size = lengthA + lengthB;
                const obj = try SnekObject.newSnekArray(allocator, size);
                for (a.data.v_array.elements, 0..) |data, index| {
                    const result = obj.data.v_array.set(index, data);
                    if (result) {
                        return error.UnableToSetArrayValue;
                    }
                }
                for (b.data.v_array.elements, 0..) |data, index| {
                    const result = obj.data.v_array.set(a.data.v_array.size + index + index, data);
                    if (result) {
                        return error.UnableToSetArrayValue;
                    }
                }
                return obj;
            } else {
                return error.InvalidTypeForAddition;
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
    const obj = try SnekObject.newSnekInteger(allocator, 0);
    defer allocator.destroy(obj);
    try expect(obj.kind == SnekObjectKind.INTEGER);
    try expect(obj.data.v_int == 0);
}
test "test integer positive" {
    const allocator = std.testing.allocator;
    const obj = try SnekObject.newSnekInteger(allocator, 17);
    defer allocator.destroy(obj);
    try expect(obj.kind == SnekObjectKind.INTEGER);
    try expect(obj.data.v_int == 17);
}
test "test integer negative" {
    const allocator = std.testing.allocator;
    const obj = try SnekObject.newSnekInteger(allocator, -17);
    defer allocator.destroy(obj);
    try expect(obj.kind == SnekObjectKind.INTEGER);
    try expect(obj.data.v_int == -17);
}

test "test float zero" {
    const allocator = std.testing.allocator;
    const obj = try SnekObject.newSnekFloat(allocator, 0.0);
    defer allocator.destroy(obj);
    try expect(obj.kind == SnekObjectKind.FLOAT);
    try expect(obj.data.v_float == 0.0);
}
test "test float positive" {
    const allocator = std.testing.allocator;
    const obj = try SnekObject.newSnekFloat(allocator, 35.12);
    defer allocator.destroy(obj);
    try expect(obj.kind == SnekObjectKind.FLOAT);
    try expect(obj.data.v_float == 35.12);
}
test "test float negative" {
    const allocator = std.testing.allocator;
    const obj = try SnekObject.newSnekFloat(allocator, -97.15);
    defer allocator.destroy(obj);
    try expect(obj.kind == SnekObjectKind.FLOAT);
    try expect(obj.data.v_float == -97.15);
}

test "test string allocation" {
    const value: []const u8 = "Hello this is test for strings in gc in Zig";
    const allocator = std.testing.allocator;
    const obj = try SnekObject.newSnekString(allocator, value);
    defer allocator.destroy(obj);
    try expect(obj.kind == SnekObjectKind.STRING);
    try expect(!(&obj.data.v_string == &value));
    try expect(std.mem.eql(u8, obj.data.v_string, value));
}

test "test vector object type" {
    const allocator = std.testing.allocator;
    const x = try SnekObject.newSnekInteger(allocator, 1);
    defer allocator.destroy(x);
    const y = try SnekObject.newSnekInteger(allocator, 2);
    defer allocator.destroy(y);
    const z = try SnekObject.newSnekInteger(allocator, 3);
    defer allocator.destroy(z);
    const obj = try SnekObject.newSnekVector3(allocator, x, y, z);
    defer allocator.destroy(obj);
    try expect(obj.data.v_vector3.x == x);
    try expect(obj.data.v_vector3.y == y);
    try expect(obj.data.v_vector3.z == z);
    try expect(obj.data.v_vector3.x.data.v_int == 1);
    try expect(obj.data.v_vector3.y.data.v_int == 2);
    try expect(obj.data.v_vector3.z.data.v_int == 3);
}

test "test array object" {
    const allocator = std.testing.allocator;
    const obj = try SnekObject.newSnekArray(allocator, 2);
    defer allocator.destroy(obj);
    defer allocator.free(obj.data.v_array.elements);
    try expect(obj.data.v_array.size == 2);
    try expect(obj.kind == SnekObjectKind.ARRAY);
}

test "test array object set and get" {
    const allocator = std.testing.allocator;
    const obj = try SnekObject.newSnekArray(allocator, 2);
    defer allocator.destroy(obj);
    defer allocator.free(obj.data.v_array.elements);
    const value1 = try SnekObject.newSnekInteger(allocator, 25);
    defer allocator.destroy(value1);
    const value2 = try SnekObject.newSnekInteger(allocator, 36);
    defer allocator.destroy(value2);
    try expect(obj.data.v_array.set(0, value1));
    try expect(obj.data.v_array.set(1, value2));

    try expect(obj.data.v_array.get(0).?.data.v_int == 25);
    try expect(obj.data.v_array.get(1).?.data.v_int == 36);

    try expect(!obj.data.v_array.set(15, value1));
    try expect(obj.data.v_array.get(13) == null);
}

test "test length function for our objects" {
    const allocator = std.testing.allocator;
    const obj_int = try SnekObject.newSnekInteger(allocator, 12);
    defer allocator.destroy(obj_int);
    const obj_float = try SnekObject.newSnekFloat(allocator, 35.6);
    defer allocator.destroy(obj_float);
    const obj_string = try SnekObject.newSnekString(allocator, "hello");
    defer allocator.destroy(obj_string);
    const x = try SnekObject.newSnekInteger(allocator, 1);
    defer allocator.destroy(x);
    const y = try SnekObject.newSnekInteger(allocator, 2);
    defer allocator.destroy(y);
    const z = try SnekObject.newSnekInteger(allocator, 3);
    defer allocator.destroy(z);
    const obj_vector = try SnekObject.newSnekVector3(allocator, x, y, z);
    defer allocator.destroy(obj_vector);
    const obj_array = try SnekObject.newSnekArray(allocator, 2);
    defer allocator.destroy(obj_array);
    defer allocator.free(obj_array.data.v_array.elements);

    try expect(length(obj_int) == 1);
    try expect(length(obj_float) == 1);
    try expect(length(obj_string) == 5);
    try expect(length(obj_vector) == 3);
    try expect(length(obj_array) == 2);
}

test "test add for integer" {
    const allocator = std.testing.allocator;
    const val_1 = try SnekObject.newSnekInteger(allocator, 34);
    defer allocator.destroy(val_1);
    const val_2 = try SnekObject.newSnekInteger(allocator, 40);
    defer allocator.destroy(val_2);
    const result = try add(allocator, val_1, val_2);
    defer allocator.destroy(result);
    const float_val_2 = try SnekObject.newSnekFloat(allocator, 40.3);
    defer allocator.destroy(float_val_2);
    const float_result = try add(allocator, val_1, float_val_2);
    defer allocator.destroy(float_result);
    try expect(result.kind == SnekObjectKind.INTEGER);
    try expect(result.data.v_int == 74);
    try expect(float_result.kind == SnekObjectKind.FLOAT);
    try expect(float_result.data.v_float == 74.3);
}

test "test add for float" {
    const allocator = std.testing.allocator;
    const val_1 = try SnekObject.newSnekFloat(allocator, 34.3);
    defer allocator.destroy(val_1);
    const val_2 = try SnekObject.newSnekFloat(allocator, 40.3);
    defer allocator.destroy(val_2);
    const result = try add(allocator, val_1, val_2);
    defer allocator.destroy(result);
    const int_val_2 = try SnekObject.newSnekInteger(allocator, 40);
    defer allocator.destroy(int_val_2);
    const float_result = try add(allocator, val_1, int_val_2);
    defer allocator.destroy(float_result);
    try expect(result.kind == SnekObjectKind.FLOAT);
    try expect(result.data.v_float == 74.6);
    try expect(float_result.kind == SnekObjectKind.FLOAT);
    try expect(float_result.data.v_float == 74.3);
}

test "test add for string" {
    const allocator = std.testing.allocator;
    const val_1 = try SnekObject.newSnekString(allocator, "Hello");
    defer allocator.destroy(val_1);
    const val_2 = try SnekObject.newSnekString(allocator, " World");
    defer allocator.destroy(val_2);
    const result = try add(allocator, val_1, val_2);
    defer allocator.destroy(result);
    defer allocator.free(result.data.v_string);
    try expect(result.kind == SnekObjectKind.STRING);
}

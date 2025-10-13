const std = @import("std");
const expect = std.testing.expect;

const SnekObjectKind = enum {
    INTEGER,
    FLOAT,
    STRING,
    VECTOR3,
};

 const SnekObjectData = union {
    v_int: i64,
    v_float: f64,
    v_string: []const u8,
    v_vector3: SnekVector,
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
    fn newSnekVector3(allocator: std.mem.Allocator, x:*SnekObject,y: *SnekObject, z:*SnekObject) !*SnekObject {
        var obj = try allocator.create(SnekObject);
        obj.kind = SnekObjectKind.VECTOR3;
         const value = SnekVector{
        .x = x,
        .y = y,
        .z = z
    };
        obj.data = SnekObjectData{ .v_vector3 = value };
        return obj;
    }
};

const SnekVector = struct {
    x:*SnekObject,
    y:*SnekObject,
    z:*SnekObject,
};

test "test integer object" {
    var allocator = std.testing.allocator;
    var obj = try allocator.create(SnekObject);
    defer allocator.destroy(obj);
    obj.kind = SnekObjectKind.INTEGER;
    obj.data = SnekObjectData{
        .v_int = 0
    };
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
    const value:[]const u8 = "Hello this is test for strings in gc in Zig";
    const allocator = std.testing.allocator;
    const obj = try SnekObject.newSnekString(allocator, value);
    defer allocator.destroy(obj);
    try expect(obj.kind == SnekObjectKind.STRING);
    try expect(!(&obj.data.v_string == &value));
    try expect(std.mem.eql(u8, obj.data.v_string, value));
}

test "test vector object type"{
    const allocator = std.testing.allocator;
    const x = try SnekObject.newSnekInteger(allocator, 1);
    defer allocator.destroy(x);
    const y = try SnekObject.newSnekInteger(allocator, 2);
    defer allocator.destroy(y);
    const z = try SnekObject.newSnekInteger(allocator, 3);
    defer allocator.destroy(z);
    const obj = try SnekObject.newSnekVector3(allocator, x,y,z);
    defer allocator.destroy(obj);
    try expect(obj.data.v_vector3.x==x);
    try expect(obj.data.v_vector3.y==y);
    try expect(obj.data.v_vector3.z==z);
     try expect(obj.data.v_vector3.x.data.v_int==1);
    try expect(obj.data.v_vector3.y.data.v_int==2);
    try expect(obj.data.v_vector3.z.data.v_int==3);

}
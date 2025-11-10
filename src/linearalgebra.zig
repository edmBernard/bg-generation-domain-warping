const std = @import("std");

pub const vec_len = std.simd.suggestVectorLength(u8) orelse @panic("No SIMD?");
pub const InnerType: type = @Vector(vec_len, f32);

pub inline fn f32_v(scalar: f32) InnerType {
    return @splat(scalar);
}

// MARK: Helper 1D functions
pub inline fn fract(x: InnerType) InnerType {
    return x - @abs(std.math.floor(x)) * std.math.sign(x);
}

// MARK: Vec2
pub const Vec2 = struct {
    x: InnerType,
    y: InnerType,

    pub inline fn mul1(a: Vec2, b: InnerType) Vec2 {
        return .{
            .x = a.x * b,
            .y = a.y * b,
        };
    }

    pub inline fn add1(a: Vec2, b: InnerType) Vec2 {
        return .{
            .x = a.x + b,
            .y = a.y + b,
        };
    }

    pub inline fn add(a: Vec2, b: Vec2) Vec2 {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
        };
    }

    pub inline fn dot(p: Vec2, q: Vec2) InnerType {
        return p.x * q.x + p.y * q.y;
    }
};

// MARK: Vec3
pub const Vec3 = struct {
    x: InnerType,
    y: InnerType,
    z: InnerType,

    pub inline fn ones() Vec3 {
        return .{ .x = f32_v(1.0), .y = f32_v(1.0), .z = f32_v(1.0) };
    }

    pub inline fn mul1(a: Vec3, b: InnerType) Vec3 {
        return .{
            .x = a.x * b,
            .y = a.y * b,
            .z = a.z * b,
        };
    }

    pub inline fn mul(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.x * b.x,
            .y = a.y * b.y,
            .z = a.z * b.z,
        };
    }

    pub inline fn add1(a: Vec3, b: InnerType) Vec3 {
        return .{
            .x = a.x + b,
            .y = a.y + b,
            .z = a.z + b,
        };
    }

    pub inline fn add(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
            .z = a.z + b.z,
        };
    }

    pub inline fn dot(p: Vec3, q: Vec3) InnerType {
        return p.x * q.x + p.y * q.y + p.z * q.z;
    }

    pub inline fn normalize(v: Vec3) Vec3 {
        const len = @sqrt(Vec3.dot(v, v));
        return .{
            .x = v.x / len,
            .y = v.y / len,
            .z = v.z / len,
        };
    }

    pub inline fn lerp(a: Vec3, b: Vec3, t: InnerType) Vec3 {
        return .{
            .x = std.math.lerp(a.x, b.x, t),
            .y = std.math.lerp(a.y, b.y, t),
            .z = std.math.lerp(a.z, b.z, t),
        };
    }

    pub inline fn pow(a: Vec3, comptime b: InnerType) Vec3 {
        return .{
            .x = std.math.pow(InnerType, a.x, b),
            .y = std.math.pow(InnerType, a.y, b),
            .z = std.math.pow(InnerType, a.z, b),
        };
    }

    // This method is not really usable
    // because lambda function in zig are not easy to declare
    pub inline fn forEach(a: Vec3, fnc: fn (InnerType) InnerType) Vec3 {
        return .{
            .x = fnc(a.x),
            .y = fnc(a.y),
            .z = fnc(a.z),
        };
    }
};

// MARK: Matrix2x2
pub const Mat2x2 = struct {
    data: [4]InnerType,
    pub inline fn mulvec2(m: Mat2x2, b: Vec2) Vec2 {
        return .{
            .x = m.data[0] * b.x + m.data[1] * b.y,
            .y = m.data[2] * b.x + m.data[3] * b.y,
        };
    }
};

// MARK: Tests

test "Vec2 Mul1 Static Method" {
    const v = Vec2{ .x = 2.0, .y = 3.0 };
    const r = Vec2.mul1(v, 4.0);
    try std.testing.expect(r.x == 8.0);
    try std.testing.expect(r.y == 12.0);
}

test "Vec2 Mul1 Method" {
    const v = Vec2{ .x = 2.0, .y = 3.0 };
    const r = v.mul1(4.0);
    try std.testing.expect(r.x == 8.0);
    try std.testing.expect(r.y == 12.0);
}

test "Vec2 Add1 Static Method" {
    const v = Vec2{ .x = 2.0, .y = 3.0 };
    const r = Vec2.add1(v, 4.0);
    try std.testing.expect(r.x == 6.0);
    try std.testing.expect(r.y == 7.0);
}

test "Vec2 Add1 Method" {
    const v = Vec2{ .x = 2.0, .y = 3.0 };
    const r = v.add1(4.0);
    try std.testing.expect(r.x == 6.0);
    try std.testing.expect(r.y == 7.0);
}

test "Vec2 Add2 Static Method" {
    const v = Vec2{ .x = 2.0, .y = 3.0 };
    const r = Vec2.add(v, Vec2{ .x = 4.0, .y = 5.0 });
    try std.testing.expect(r.x == 6.0);
    try std.testing.expect(r.y == 8.0);
}

test "Vec2 Add2 Method" {
    const v = Vec2{ .x = 2.0, .y = 3.0 };
    const r = v.add(Vec2{ .x = 4.0, .y = 5.0 });
    try std.testing.expect(r.x == 6.0);
    try std.testing.expect(r.y == 8.0);
}

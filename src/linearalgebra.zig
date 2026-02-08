const std = @import("std");
const zpp = @import("zpp");

// I use u8 and not f32 here because at the end of the processing we cast the value to u8.
// so we need enough f32 value to fill a full vector of u8 values
// I quickly also test different vector lenght and this seem the fastest
pub const vec_len = zpp.suggested_vec_len;
pub const InnerType: type = @Vector(vec_len, f32);

/// Convert a scalar to a vector by splatting it
pub inline fn toV(comptime scalar: f32) InnerType {
    return @splat(scalar);
}

// MARK: Helper 1D functions

/// Return the fractional part of a floating point number
pub inline fn fract(x: InnerType) InnerType {
    return x - @floor(x);
}

/// Perform Hermite interpolation between two values
pub inline fn smoothstep(edge0: InnerType, edge1: InnerType, x: InnerType) InnerType {
    const t = std.math.clamp((x - edge0) / (edge1 - edge0), toV(0.0), toV(1.0));
    return t * t * (toV(3.0) - toV(2.0) * t);
}

/// Perform Quintic interpolation between two values
pub inline fn supersmoothstep(edge0: InnerType, edge1: InnerType, x: InnerType) InnerType {
    const t = std.math.clamp((x - edge0) / (edge1 - edge0), toV(0.0), toV(1.0));
    return t * t * t * (t * (t * toV(6.0) - toV(15.0)) + toV(10.0));
}

// MARK: Vec2
pub const Vec2 = struct {
    x: InnerType,
    y: InnerType,

    /// a * b
    pub inline fn mul1(a: Vec2, b: InnerType) Vec2 {
        return .{
            .x = a.x * b,
            .y = a.y * b,
        };
    }

    /// a + b
    pub inline fn add1(a: Vec2, b: InnerType) Vec2 {
        return .{
            .x = a.x + b,
            .y = a.y + b,
        };
    }

    /// a + b
    pub inline fn add(a: Vec2, b: Vec2) Vec2 {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
        };
    }

    /// a - b
    pub inline fn sub1(a: Vec2, b: InnerType) Vec2 {
        return .{
            .x = a.x - b,
            .y = a.y - b,
        };
    }

    /// a - b
    pub inline fn sub(a: Vec2, b: Vec2) Vec2 {
        return .{
            .x = a.x - b.x,
            .y = a.y - b.y,
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
        return .{ .x = toV(1.0), .y = toV(1.0), .z = toV(1.0) };
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

    pub inline fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.x - b.x,
            .y = a.y - b.y,
            .z = a.z - b.z,
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

    /// Power function for integer exponents
    pub inline fn pow(a: Vec3, comptime b: u32) Vec3 {
        if (comptime b == 0) {
            return Vec3.ones();
        }
        var res = a;
        inline for (1..b) |_| {
            res = res.mul(a);
        }
        return res;
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

// MARK: Tests Vec2

test "Vec2 Mul1 Static Method" {
    const v = Vec2{ .x = toV(2.0), .y = toV(3.0) };
    const r = Vec2.mul1(v, toV(4.0));
    try std.testing.expect(std.meta.eql(r.x, toV(8.0)));
    try std.testing.expect(std.meta.eql(r.y, toV(12.0)));
}

test "Vec2 Mul1 Method" {
    const v = Vec2{ .x = toV(2.0), .y = toV(3.0) };
    const r = v.mul1(toV(4.0));
    try std.testing.expect(std.meta.eql(r.x, toV(8.0)));
    try std.testing.expect(std.meta.eql(r.y, toV(12.0)));
}

test "Vec2 Add1 Static Method" {
    const v = Vec2{ .x = toV(2.0), .y = toV(3.0) };
    const r = Vec2.add1(v, toV(4.0));
    try std.testing.expect(std.meta.eql(r.x, toV(6.0)));
    try std.testing.expect(std.meta.eql(r.y, toV(7.0)));
}

test "Vec2 Add1 Method" {
    const v = Vec2{ .x = toV(2.0), .y = toV(3.0) };
    const r = v.add1(toV(4.0));
    try std.testing.expect(std.meta.eql(r.x, toV(6.0)));
    try std.testing.expect(std.meta.eql(r.y, toV(7.0)));
}

test "Vec2 Add Static Method" {
    const v = Vec2{ .x = toV(2.0), .y = toV(3.0) };
    const r = Vec2.add(v, Vec2{ .x = toV(4.0), .y = toV(5.0) });
    try std.testing.expect(std.meta.eql(r.x, toV(6.0)));
    try std.testing.expect(std.meta.eql(r.y, toV(8.0)));
}

test "Vec2 Add Method" {
    const v = Vec2{ .x = toV(2.0), .y = toV(3.0) };
    const r = v.add(Vec2{ .x = toV(4.0), .y = toV(5.0) });
    try std.testing.expect(std.meta.eql(r.x, toV(6.0)));
    try std.testing.expect(std.meta.eql(r.y, toV(8.0)));
}

// MARK: Tests Vec3

test "Vec3 Pow Method" {
    const v = Vec3{ .x = toV(-2.0), .y = toV(2.0), .z = toV(3.0) };

    const r0 = v.pow(0);
    try std.testing.expect(std.meta.eql(r0.x, toV(1.0)));
    try std.testing.expect(std.meta.eql(r0.y, toV(1.0)));
    try std.testing.expect(std.meta.eql(r0.z, toV(1.0)));

    const r3 = v.pow(3);
    try std.testing.expect(std.meta.eql(r3.x, toV(-8.0)));
    try std.testing.expect(std.meta.eql(r3.y, toV(8.0)));
    try std.testing.expect(std.meta.eql(r3.z, toV(27.0)));

    const r10 = v.pow(10);
    try std.testing.expect(std.meta.eql(r10.x, toV(1024.0)));
    try std.testing.expect(std.meta.eql(r10.y, toV(1024.0)));
    try std.testing.expect(std.meta.eql(r10.z, toV(59049.0)));
}

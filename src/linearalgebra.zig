const std = @import("std");

// MARK: Helper 1D functions
pub inline fn fract(x: f32) f32 {
    return x - @abs(std.math.floor(x)) * std.math.sign(x);
}

// MARK: Vec2
pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub inline fn mul1(a: Vec2, b: f32) Vec2 {
        return .{
            .x = a.x * b,
            .y = a.y * b,
        };
    }

    pub inline fn add1(a: Vec2, b: f32) Vec2 {
        return .{
            .x = a.x + b,
            .y = a.y + b,
        };
    }

    pub inline fn dot(p: Vec2, q: Vec2) f32 {
        return p.x * q.x + p.y * q.y;
    }
};

// MARK: Vec3
pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn mul1(a: Vec3, b: f32) Vec3 {
        return .{
            .x = a.x * b,
            .y = a.y * b,
            .z = a.z * b,
        };
    }

    pub inline fn add1(a: Vec3, b: f32) Vec3 {
        return .{
            .x = a.x + b,
            .y = a.y + b,
            .z = a.z + b,
        };
    }

    pub inline fn dot(p: Vec3, q: Vec3) f32 {
        return p.x * q.x + p.y * q.y + p.z * q.z;
    }

    pub inline fn normalize(v: Vec3) Vec3 {
        const len = std.math.sqrt(Vec3.dot(v, v));
        return .{
            .x = v.x / len,
            .y = v.y / len,
            .z = v.z / len,
        };
    }

    pub inline fn lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
        return .{
            .x = std.math.lerp(a.x, b.x, t),
            .y = std.math.lerp(a.y, b.y, t),
            .z = std.math.lerp(a.z, b.z, t),
        };
    }
};

// MARK: Matrix2x2
pub inline fn matmul(m: [4]f32, b: Vec2) Vec2 {
    return .{
        .x = m[0] * b.x + m[1] * b.y,
        .y = m[2] * b.x + m[3] * b.y,
    };
}

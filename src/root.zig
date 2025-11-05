//! Simplex noise and fbm implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
const std = @import("std");
pub const PatternType = @import("types").PatternType;

const Vec2 = struct {
    x: f32,
    y: f32,
};
const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

inline fn mul(a: Vec2, b: f32) Vec2 {
    return .{
        .x = a.x * b,
        .y = a.y * b,
    };
}
inline fn add(a: Vec2, b: f32) Vec2 {
    return .{
        .x = a.x + b,
        .y = a.y + b,
    };
}

inline fn fract(x: f32) f32 {
    return x - @abs(std.math.floor(x)) * std.math.sign(x);
}

fn dot2(p: Vec2, q: Vec2) f32 {
    return p.x * q.x + p.y * q.y;
}

fn dot3(p: Vec3, q: Vec3) f32 {
    return p.x * q.x + p.y * q.y + p.z * q.z;
}

fn hash(p: Vec2) Vec2 {
    const temp = .{ .x = dot2(p, .{ .x = 127.1, .y = 311.7 }), .y = dot2(p, .{ .x = 269.5, .y = 183.3 }) };
    return .{
        .x = -1.0 + 2.0 * fract(std.math.sin(temp.x) * 43758.5453123),
        .y = -1.0 + 2.0 * fract(std.math.sin(temp.y) * 43758.5453123),
    };
}

// Simplex noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
fn noise(p: Vec2) f32 {
    const K1 = 0.366025404; // (sqrt(3)-1)/2;
    const K2 = 0.211324865; // (3-sqrt(3))/6;

    const i: Vec2 = .{ .x = std.math.floor(p.x + (p.x + p.y) * K1), .y = std.math.floor(p.y + (p.x + p.y) * K1) };
    const a: Vec2 = .{ .x = p.x - i.x + (i.x + i.y) * K2, .y = p.y - i.y + (i.x + i.y) * K2 };
    const m: f32 = if (a.x < a.y) 0 else 1;
    const o: Vec2 = .{ .x = m, .y = 1.0 - m };
    const b: Vec2 = .{ .x = a.x - o.x + K2, .y = a.y - o.y + K2 };
    const c: Vec2 = .{ .x = a.x - 1.0 + 2.0 * K2, .y = a.y - 1.0 + 2.0 * K2 };
    const h: Vec3 = .{
        .x = @max(0.5 - dot2(a, a), 0),
        .y = @max(0.5 - dot2(b, b), 0),
        .z = @max(0.5 - dot2(c, c), 0),
    };
    const n: Vec3 = .{
        .x = h.x * h.x * h.x * h.x * dot2(a, hash(.{ .x = i.x + 0.0, .y = i.y + 0.0 })),
        .y = h.y * h.y * h.y * h.y * dot2(b, hash(.{ .x = i.x + o.x, .y = i.y + o.y })),
        .z = h.z * h.z * h.z * h.z * dot2(c, hash(.{ .x = i.x + 1.0, .y = i.y + 1.0 })),
    };
    return dot3(n, .{ .x = 70, .y = 70, .z = 70 }); // does this line is really correct (70, 0, 0) ?
}

const numOctaves = 6;

// fbm noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
fn fbm(vec: Vec2) f32 {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 0.5;
    const G = std.math.exp2(-H);
    var f: f32 = 1.0;
    var a: f32 = 1.0;
    var t: f32 = 0.0;
    for (0..numOctaves) |_| {
        t += a * noise(mul(vec, f));
        f *= 2.0;
        a *= G;
    }
    return t;
}

fn pattern1(p: Vec2) f32 {
    return fbm(p);
}

fn pattern2(p: Vec2) f32 {
    const q: Vec2 = .{
        .x = fbm(.{ .x = p.x + 0, .y = p.y + 0 }),
        .y = fbm(.{ .x = p.x + 5.2, .y = p.y + 1.3 }),
    };

    return fbm(.{
        .x = p.x + 4.0 * q.x,
        .y = p.y + 4.0 * q.y,
    });
}

fn pattern3(p: Vec2) f32 {
    const q: Vec2 = .{
        .x = fbm(.{ .x = p.x + 0, .y = p.y + 0 }),
        .y = fbm(.{ .x = p.x + 5.2, .y = p.y + 1.3 }),
    };

    const r: Vec2 = .{
        .x = fbm(.{ .x = p.x + 4.0 * q.x + 1.7, .y = p.y + 4.0 * q.y + 9.2 }),
        .y = fbm(.{ .x = p.x + 4.0 * q.x + 8.3, .y = p.y + 4.0 * q.y + 2.8 }),
    };

    return fbm(.{
        .x = p.x + 4.0 * r.x,
        .y = p.y + 4.0 * r.y,
    });
}

pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32, pattern: PatternType) !std.ArrayList(u8) {
    var data = try std.ArrayList(u8).initCapacity(allocator, width * height);
    data.appendNTimesAssumeCapacity(0, width * height);

    const scale: f32 = switch (pattern) {
        PatternType.k1 => 100.0,
        PatternType.k2 => 1000.0,
        PatternType.k3 => 8000.0,
    };
    for (0..height) |i| {
        for (0..width) |j| {
            const x = @as(f32, @floatFromInt(j)) / @as(f32, (scale));
            const y = @as(f32, @floatFromInt(i)) / @as(f32, (scale));

            const value = switch (pattern) {
                PatternType.k1 => pattern1(.{ .x = x, .y = y }),
                PatternType.k2 => pattern2(.{ .x = x, .y = y }),
                PatternType.k3 => pattern3(.{ .x = x, .y = y }),
            };
            data.items[i * width + j] = @as(u8, @intFromFloat(std.math.clamp((value + 1) / 2 * 255, 0, 255)));
        }
    }

    return data;
}

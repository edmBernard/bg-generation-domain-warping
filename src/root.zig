//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

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
fn fbm(vec: Vec2, H: f32) f32 {
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

pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32) !std.ArrayList(u8) {
    var data = try std.ArrayList(u8).initCapacity(allocator, width * height);
    data.appendNTimesAssumeCapacity(0, width * height);

    const scale = 100.0;
    for (0..height) |i| {
        for (0..width) |j| {
            const x = @as(f32, @floatFromInt(j)) / @as(f32, (scale));
            const y = @as(f32, @floatFromInt(i)) / @as(f32, (scale));
            const value = fbm(.{ .x = x, .y = y }, 0.7);
            // std.debug.print("fbm value {}\n", .{value});
            data.items[i * width + j] = @as(u8, @intFromFloat(std.math.clamp((value + 1) / 2 * 255, 0, 255)));
        }
    }

    return data;
}

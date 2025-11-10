const std = @import("std");
const laz = @import("linearalgebra.zig");

fn hash(p: laz.Vec2) laz.Vec2 {
    const temp = .{ .x = laz.Vec2.dot(p, .{ .x = 127.1, .y = 311.7 }), .y = laz.Vec2.dot(p, .{ .x = 269.5, .y = 183.3 }) };
    return .{
        .x = -1.0 + 2.0 * laz.fract(std.math.sin(temp.x) * 43758.5453123),
        .y = -1.0 + 2.0 * laz.fract(std.math.sin(temp.y) * 43758.5453123),
    };
}

// Simplex noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
pub fn noise(p: laz.Vec2) f32 {
    const K1 = 0.366025404; // (sqrt(3)-1)/2;
    const K2 = 0.211324865; // (3-sqrt(3))/6;

    const i: laz.Vec2 = .{ .x = std.math.floor(p.x + (p.x + p.y) * K1), .y = std.math.floor(p.y + (p.x + p.y) * K1) };
    const a: laz.Vec2 = .{ .x = p.x - i.x + (i.x + i.y) * K2, .y = p.y - i.y + (i.x + i.y) * K2 };
    const m: f32 = if (a.x < a.y) 0 else 1;
    const o: laz.Vec2 = .{ .x = m, .y = 1.0 - m };
    const b: laz.Vec2 = .{ .x = a.x - o.x + K2, .y = a.y - o.y + K2 };
    const c: laz.Vec2 = .{ .x = a.x - 1.0 + 2.0 * K2, .y = a.y - 1.0 + 2.0 * K2 };
    const h: laz.Vec3 = .{
        .x = @max(0.5 - laz.Vec2.dot(a, a), 0),
        .y = @max(0.5 - laz.Vec2.dot(b, b), 0),
        .z = @max(0.5 - laz.Vec2.dot(c, c), 0),
    };
    const n: laz.Vec3 = .{
        .x = h.x * h.x * h.x * h.x * laz.Vec2.dot(a, hash(.{ .x = i.x + 0.0, .y = i.y + 0.0 })),
        .y = h.y * h.y * h.y * h.y * laz.Vec2.dot(b, hash(.{ .x = i.x + o.x, .y = i.y + o.y })),
        .z = h.z * h.z * h.z * h.z * laz.Vec2.dot(c, hash(.{ .x = i.x + 1.0, .y = i.y + 1.0 })),
    };
    return laz.Vec3.dot(n, .{ .x = 70, .y = 70, .z = 70 });
}

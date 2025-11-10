const std = @import("std");
const laz = @import("linearalgebra.zig");

fn hash(p: laz.Vec2) laz.Vec2 {
    const temp = .{
        .x = laz.Vec2.dot(p, .{ .x = laz.f32_v(127.1), .y = laz.f32_v(311.7) }),
        .y = laz.Vec2.dot(p, .{ .x = laz.f32_v(269.5), .y = laz.f32_v(183.3) }),
    };
    return .{
        .x = laz.f32_v(-1.0) + laz.f32_v(2.0) * laz.fract(std.math.sin(temp.x) * laz.f32_v(43758.5453123)),
        .y = laz.f32_v(-1.0) + laz.f32_v(2.0) * laz.fract(std.math.sin(temp.y) * laz.f32_v(43758.5453123)),
    };
}

// Simplex noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
pub fn noise(p: laz.Vec2) laz.InnerType {
    // Constant for triangle mapping
    const K1 = laz.f32_v(0.366025404); // (sqrt(3)-1)/2;
    const K2 = laz.f32_v(0.211324865); // (3-sqrt(3))/6;

    const i: laz.Vec2 = .{ .x = std.math.floor(p.x + (p.x + p.y) * K1), .y = std.math.floor(p.y + (p.x + p.y) * K1) };
    const a: laz.Vec2 = .{ .x = p.x - i.x + (i.x + i.y) * K2, .y = p.y - i.y + (i.x + i.y) * K2 };
    const m: laz.InnerType = @select(f32, a.x < a.y, laz.f32_v(0), laz.f32_v(1));
    const o: laz.Vec2 = .{ .x = m, .y = laz.f32_v(1.0) - m };
    const b: laz.Vec2 = .{ .x = a.x - o.x + K2, .y = a.y - o.y + K2 };
    const c: laz.Vec2 = .{ .x = a.x - laz.f32_v(1.0) + laz.f32_v(2.0) * K2, .y = a.y - laz.f32_v(1.0) + laz.f32_v(2.0) * K2 };
    const h: laz.Vec3 = .{
        .x = @max(laz.f32_v(0.5) - laz.Vec2.dot(a, a), laz.f32_v(0)),
        .y = @max(laz.f32_v(0.5) - laz.Vec2.dot(b, b), laz.f32_v(0)),
        .z = @max(laz.f32_v(0.5) - laz.Vec2.dot(c, c), laz.f32_v(0)),
    };
    const n: laz.Vec3 = .{
        .x = h.x * h.x * h.x * h.x * laz.Vec2.dot(a, hash(.{ .x = i.x + laz.f32_v(0.0), .y = i.y + laz.f32_v(0.0) })),
        .y = h.y * h.y * h.y * h.y * laz.Vec2.dot(b, hash(.{ .x = i.x + o.x, .y = i.y + o.y })),
        .z = h.z * h.z * h.z * h.z * laz.Vec2.dot(c, hash(.{ .x = i.x + laz.f32_v(1.0), .y = i.y + laz.f32_v(1.0) })),
    };
    return laz.Vec3.dot(n, .{ .x = laz.f32_v(70), .y = laz.f32_v(70), .z = laz.f32_v(70) });
}

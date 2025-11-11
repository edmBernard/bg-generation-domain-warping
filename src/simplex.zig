const std = @import("std");

/// Makes all vector types generic against f32 and simd vector of f32
pub fn as(comptime InnerType: type) type {
    const laz = @import("linearalgebra").as(InnerType);
    return struct {
        /// A periodic triangle function
        /// using this instead of sin improve performance by a factor 5 on the whole generation
        /// and result are similar enough
        inline fn triangle_func(in: InnerType) InnerType {
            const z = in * laz.toS(0.25);
            const f = laz.toS(2.0) * @abs(z - @floor(z) - laz.toS(0.5));
            return laz.toS(2.0) * f - laz.toS(1.0);
        }

        /// A periodic function that look like a sin with a period of 2
        /// Same as triangle_func but with an easing function to make it like a sine wave
        inline fn periodic_func(in: InnerType) InnerType {
            const z = in * laz.toS(0.25);
            const f = laz.toS(2.0) * @abs(z - @floor(z) - laz.toS(0.5));
            const g = f * f * (laz.toS(3.0) - laz.toS(2.0) * f);
            return laz.toS(2.0) * g - laz.toS(1.0);
        }

        inline fn hash(p: laz.Vec2) laz.Vec2 {
            const temp = .{
                .x = laz.Vec2.dot(p, .{ .x = laz.toS(127.1), .y = laz.toS(311.7) }),
                .y = laz.Vec2.dot(p, .{ .x = laz.toS(269.5), .y = laz.toS(183.3) }),
            };
            return .{
                .x = laz.toS(-1.0) + laz.toS(2.0) * laz.fract(triangle_func(temp.x) * laz.toS(43758.5453123)),
                .y = laz.toS(-1.0) + laz.toS(2.0) * laz.fract(triangle_func(temp.y) * laz.toS(43758.5453123)),
            };
        }

        /// Simplex noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
        pub fn noise(p: laz.Vec2) InnerType {
            // Constant for triangle mapping
            const K1 = laz.toS(0.366025404); // (sqrt(3)-1)/2;
            const K2 = laz.toS(0.211324865); // (3-sqrt(3))/6;

            const i: laz.Vec2 = .{ .x = @floor(p.x + (p.x + p.y) * K1), .y = @floor(p.y + (p.x + p.y) * K1) };
            const a: laz.Vec2 = .{ .x = p.x - i.x + (i.x + i.y) * K2, .y = p.y - i.y + (i.x + i.y) * K2 };
            const m: InnerType = @select(f32, a.x < a.y, laz.toS(0), laz.toS(1));
            const o: laz.Vec2 = .{ .x = m, .y = laz.toS(1.0) - m };
            const b: laz.Vec2 = .{ .x = a.x - o.x + K2, .y = a.y - o.y + K2 };
            const c: laz.Vec2 = .{ .x = a.x - laz.toS(1.0) + laz.toS(2.0) * K2, .y = a.y - laz.toS(1.0) + laz.toS(2.0) * K2 };
            const h: laz.Vec3 = .{
                .x = @max(laz.toS(0.5) - laz.Vec2.dot(a, a), laz.toS(0)),
                .y = @max(laz.toS(0.5) - laz.Vec2.dot(b, b), laz.toS(0)),
                .z = @max(laz.toS(0.5) - laz.Vec2.dot(c, c), laz.toS(0)),
            };
            const n: laz.Vec3 = .{
                .x = h.x * h.x * h.x * h.x * laz.Vec2.dot(a, hash(.{ .x = i.x + laz.toS(0.0), .y = i.y + laz.toS(0.0) })),
                .y = h.y * h.y * h.y * h.y * laz.Vec2.dot(b, hash(.{ .x = i.x + o.x, .y = i.y + o.y })),
                .z = h.z * h.z * h.z * h.z * laz.Vec2.dot(c, hash(.{ .x = i.x + laz.toS(1.0), .y = i.y + laz.toS(1.0) })),
            };
            return laz.Vec3.dot(n, .{ .x = laz.toS(70), .y = laz.toS(70), .z = laz.toS(70) });
        }
    };
}

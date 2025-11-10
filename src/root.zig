//! Simplex noise and fbm implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
const std = @import("std");
const laz = @import("linearalgebra.zig");
const simplex = @import("simplex.zig");

/// The hex color is in format 0xRRGGBBAA
inline fn hexToVec3(comptime hex: u32) laz.Vec3 {
    return .{
        .x = laz.f32_v(@as(f32, @floatFromInt((hex & 0xFF000000) >> 24)) / 255.0),
        .y = laz.f32_v(@as(f32, @floatFromInt((hex & 0x00FF0000) >> 16)) / 255.0),
        .z = laz.f32_v(@as(f32, @floatFromInt((hex & 0x0000FF00) >> 8)) / 255.0),
    };
}

// perform Hermite interpolation between two values
inline fn smoothstep(edge0: laz.InnerType, edge1: laz.InnerType, x: laz.InnerType) laz.InnerType {
    const t = std.math.clamp((x - edge0) / (edge1 - edge0), laz.f32_v(0.0), laz.f32_v(1.0));
    return t * t * (laz.f32_v(3.0) - laz.f32_v(2.0) * t);
}

inline fn supersmoothstep(edge0: laz.InnerType, edge1: laz.InnerType, x: laz.InnerType) laz.InnerType {
    const t = std.math.clamp((x - edge0) / (edge1 - edge0), laz.f32_v(0.0), laz.f32_v(1.0));
    return t * t * t * (laz.f32_v(10.0) - laz.f32_v(15.0) * t + laz.f32_v(6.0) * t * t);
}

// rotation matrix to avoid direction artifacts
const angle = std.math.pi / 4.0;
const mtx = laz.Mat2x2{
    .data = [4]laz.InnerType{
        @splat(@cos(angle)),
        @splat(@sin(angle)),
        @splat(-@sin(angle)),
        @splat(@cos(angle)),
    },
};

// fbm noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
fn fbm(comptime octaves: i32, vec: laz.Vec2) laz.InnerType {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 1.0; // change a lot the visual aspect
    const G = laz.f32_v(std.math.exp2(-H));
    var f = laz.f32_v(1.0);
    var a = laz.f32_v(0.5);
    var t = laz.f32_v(0.0);
    for (0..octaves) |_| {
        t += a * simplex.noise(mtx.mulvec2(vec).mul1(f));
        f *= laz.f32_v(1.9);
        a *= G;
    }
    return t;
}

fn fbm6(vec: laz.Vec2) laz.InnerType {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 1.0; // change a lot the visual aspect
    const G = laz.f32_v(std.math.exp2(-H));
    var f = laz.f32_v(1.0);
    var a = laz.f32_v(0.5);
    var t = laz.f32_v(0.0);
    for (0..6) |_| {
        t += a * simplex.noise(mtx.mulvec2(vec).mul1(f));
        f *= laz.f32_v(2.1);
        a *= G;
    }
    return t * laz.f32_v(1.1);
}

fn pattern3(p: laz.Vec2) struct { laz.InnerType, laz.Vec2, laz.Vec2 } {
    // low frequency
    const q: laz.Vec2 = .{
        .x = laz.f32_v(0.5) + laz.f32_v(0.5) * fbm(4, .{ .x = p.x + laz.f32_v(1.0), .y = p.y + laz.f32_v(0.1) }),
        .y = laz.f32_v(0.5) + laz.f32_v(0.5) * fbm(4, .{ .x = p.x + laz.f32_v(5.2), .y = p.y + laz.f32_v(1.3) }),
    };

    // mid frequency
    const r: laz.Vec2 = .{
        .x = laz.f32_v(0.5) - laz.f32_v(0.5) * fbm6(.{ .x = laz.f32_v(4.1) * q.x, .y = laz.f32_v(4.1) * q.y }),
        .y = laz.f32_v(0.5) - laz.f32_v(0.5) * fbm6(.{ .x = laz.f32_v(4.1) * q.x, .y = laz.f32_v(4.1) * q.y }),
    };

    // high frequency
    const f = laz.f32_v(0.5) + laz.f32_v(0.5) * fbm(4, p.add(r.mul1(laz.f32_v(2.1))));
    return .{ f, r, q };
}

pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32) !std.ArrayList(u8) {
    var data = try std.ArrayList(u8).initCapacity(allocator, width * height * 3);
    data.appendNTimesAssumeCapacity(0, width * height * 3);

    const scale = laz.f32_v(1000.0);
    const time = 125.0;
    const sin_time = laz.f32_v(std.math.sin(time));

    const iota = std.simd.iota(f32, laz.vec_len);

    for (0..height) |i| {
        const y: laz.InnerType = @as(laz.InnerType, @splat(@as(f32, @floatFromInt(i)))) / scale + sin_time;

        for (0..width / laz.vec_len) |j| {
            const x = (iota + @as(laz.InnerType, @splat(@as(f32, @floatFromInt(j * laz.vec_len))))) / scale + sin_time;

            const r, const g, const b = blk: {
                const f, const r, const q = pattern3(.{ .x = x, .y = y });
                var col = hexToVec3(0x561111ff); // #561111ff

                col = col.lerp(hexToVec3(0xe2730cff), f); // #e2730cff
                col = col.lerp(hexToVec3(0xffffffff), laz.Vec2.dot(r, r)); // #ffffffff
                col = col.lerp(hexToVec3(0x832121ff), laz.Vec2.dot(q, q)); // #832121ff
                // col = laz.Vec3.lerp(col, hexToVec3(0x0adaffff), 0.5 * q.y * q.y); // #0adaffff
                col = col.lerp(
                    hexToVec3(0x290202ff), // #290202ff
                    laz.f32_v(0.5) * supersmoothstep(laz.f32_v(1.1), laz.f32_v(1.3), @abs(r.x) + @abs(r.y)),
                );

                // Add a lighting
                const e = laz.f32_v(1.0) / scale;
                const fex, _, _ = pattern3(.{ .x = x + e, .y = y });
                const fey, _, _ = pattern3(.{ .x = x, .y = y + e });

                // compute surface normal
                // normal.x is the derivative of pattern3 along x
                // normal.y is the derivative of pattern3 along y
                // normal.z is the step
                const normal = laz.Vec3.normalize(.{ .x = fex - f, .y = fey - f, .z = e });

                // we define a light direction
                const light = laz.Vec3.normalize(.{ .x = laz.f32_v(0.5), .y = laz.f32_v(-0.3), .z = laz.f32_v(-0.1) });
                // we compute the diffuse term
                const diff = std.math.clamp(laz.f32_v(0.5) + laz.f32_v(0.9) * laz.Vec3.dot(normal, light), laz.f32_v(0.0), laz.f32_v(1.0));
                const lin: laz.Vec3 = .{
                    .x = (normal.z * laz.f32_v(0.2) + laz.f32_v(0.7)) + laz.f32_v(0.1) * diff,
                    .y = (normal.z * laz.f32_v(0.2) + laz.f32_v(0.7)) + laz.f32_v(0.1) * diff,
                    .z = (normal.z * laz.f32_v(0.2) + laz.f32_v(0.7)) + laz.f32_v(0.1) * diff,
                };
                col = col.mul(lin);

                // increase contrast on high frequency details
                col = col.mul1(f * laz.f32_v(2.0));

                // inverse value and apply a gamma curve to boost contrast
                // std.math.pow is not vectorized
                const temp = laz.Vec3.ones().add(col.mul1(laz.f32_v(-1.0)));
                col = temp.mul(temp).mul(temp); // gamma 3
                break :blk .{ col.x, col.y, col.z };
            };

            const r_u8 = @as(@Vector(laz.vec_len, u8), @intFromFloat(std.math.clamp(r * laz.f32_v(255), laz.f32_v(0), laz.f32_v(255))));
            const g_u8 = @as(@Vector(laz.vec_len, u8), @intFromFloat(std.math.clamp(g * laz.f32_v(255), laz.f32_v(0), laz.f32_v(255))));
            const b_u8 = @as(@Vector(laz.vec_len, u8), @intFromFloat(std.math.clamp(b * laz.f32_v(255), laz.f32_v(0), laz.f32_v(255))));
            data.items[i * width * 3 + j * 3 * laz.vec_len ..][0 .. laz.vec_len * 3].* = std.simd.interlace(.{ r_u8, g_u8, b_u8 });
        }
    }

    return data;
}

//! Simplex noise and fbm implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
const std = @import("std");
const laz = @import("linearalgebra.zig");
const simplex = @import("simplex.zig");
pub const PatternType = @import("types").PatternType;

const time = 125.0;

pub fn vec3fromHexWithAlpha(hex: u32) laz.Vec3 {
    return .{
        .x = @as(f32, @floatFromInt((hex & 0xFF000000) >> 24)) / 255.0,
        .y = @as(f32, @floatFromInt((hex & 0x00FF0000) >> 16)) / 255.0,
        .z = @as(f32, @floatFromInt((hex & 0x0000FF00) >> 8)) / 255.0,
    };
}

// perform Hermite interpolation between two values
inline fn smoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    const t = std.math.clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

inline fn supersmoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    const t = std.math.clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * t * (10 - 15 * t + 6 * t * t);
}

inline fn forEach3(a: laz.Vec3, fnc: fn (f32) f32) laz.Vec3 {
    return .{
        .x = fnc(a.x),
        .y = fnc(a.y),
        .z = fnc(a.z),
    };
}

// rotation matrix to avoid direction artifacts
const angle = std.math.pi / 4.0;
const mtx = [4]f32{ @cos(angle), @sin(angle), -@sin(angle), @cos(angle) };

// fbm noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
fn fbm(comptime octaves: i32, vec: laz.Vec2) f32 {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 1.0; // change a lot the visual aspect
    const G = std.math.exp2(-H);
    var f: f32 = 1.0;
    var a: f32 = 0.5;
    var t: f32 = 0.0;
    for (0..octaves) |_| {
        t += a * simplex.noise(laz.Vec2.mul1(laz.matmul(mtx, vec), f));
        f *= 1.9;
        a *= G;
    }
    return t;
}

fn fbm6(vec: laz.Vec2) f32 {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 1.0; // change a lot the visual aspect
    const G = std.math.exp2(-H);
    // f = 1.0 f*= 2.01; nice
    // f = 2.0 f*= 1.01; nice
    var f: f32 = 1.0;
    var a: f32 = 0.5;
    var t: f32 = 0.0;
    for (0..6) |_| {
        t += a * simplex.noise(laz.Vec2.mul1(laz.matmul(mtx, vec), f));
        f *= 2.1;
        a *= G;
    }
    return t * 1.1;
}

fn pattern1(p: laz.Vec2) f32 {
    return fbm(6, p);
}

fn pattern2(p: laz.Vec2) struct { f32, laz.Vec2 } {
    const q: laz.Vec2 = .{
        .x = fbm(6, .{ .x = p.x + 0, .y = p.y + 0 }),
        .y = fbm(6, .{ .x = p.x + 5.2, .y = p.y + 1.3 }),
    };

    return .{ fbm(6, .{
        .x = p.x + 4.0 * q.x,
        .y = p.y + 4.0 * q.y,
    }), q };
}

fn pattern3(p: laz.Vec2) struct { f32, laz.Vec2, laz.Vec2 } {
    // low frequency
    const q: laz.Vec2 = .{
        .x = 0.5 + 0.5 * fbm(4, .{ .x = p.x + 1.0, .y = p.y + 0.1 }),
        .y = 0.5 + 0.5 * fbm(4, .{ .x = p.x + 5.2, .y = p.y + 1.3 }),
    };

    // mid frequency
    const r: laz.Vec2 = .{
        .x = 0.5 - 0.5 * fbm6(.{ .x = 4.1 * q.x, .y = 4.1 * q.y }),
        .y = 0.5 - 0.5 * fbm6(.{ .x = 4.1 * q.x, .y = 4.1 * q.y }),
    };

    // high frequency
    const f: f32 = 0.5 + 0.5 * fbm(4, .{
        .x = p.x + 2.1 * r.x,
        .y = p.y + 2.1 * r.y,
    });
    return .{ f, r, q };
}

pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32, pattern: PatternType) !std.ArrayList(u8) {
    var data = try std.ArrayList(u8).initCapacity(allocator, width * height * 3);
    data.appendNTimesAssumeCapacity(0, width * height * 3);

    const scale: f32 = switch (pattern) {
        PatternType.k1 => 100.0,
        PatternType.k2 => 1000.0,
        PatternType.k3 => 1000.0,
    };
    for (0..height) |i| {
        for (0..width) |j| {
            const x = @as(f32, @floatFromInt(j)) / @as(f32, (scale)) + std.math.sin(time);
            const y = @as(f32, @floatFromInt(i)) / @as(f32, (scale)) + std.math.sin(time);

            const r, const g, const b = switch (pattern) {
                PatternType.k1 => blk: {
                    const f = pattern1(.{ .x = x, .y = y });
                    break :blk .{ f, f, f };
                },
                PatternType.k2 => blk: {
                    const f, const q = pattern2(.{ .x = x, .y = y });
                    var col = vec3fromHexWithAlpha(0xd88314ff); // #d88314ff
                    col = laz.Vec3.lerp(col, vec3fromHexWithAlpha(0x4c402fff), f); // #4c402fff
                    col = laz.Vec3.lerp(col, vec3fromHexWithAlpha(0x760404ff), laz.Vec2.dot(q, q)); // #760404ff
                    const functor = struct {
                        pub fn call(value: f32) f32 {
                            return value * value;
                        }
                    }.call;
                    col = forEach3(col, functor);
                    break :blk .{ col.x, col.y, col.z };
                },
                PatternType.k3 => blk: {
                    const f, const r, const q = pattern3(.{ .x = x, .y = y });
                    var col = vec3fromHexWithAlpha(0x561111ff); // #561111ff

                    // _ = f;
                    // _ = r;
                    // _ = q;
                    col = laz.Vec3.lerp(col, vec3fromHexWithAlpha(0xe2730cff), f); // #e2730cff
                    col = laz.Vec3.lerp(col, vec3fromHexWithAlpha(0xffffffff), laz.Vec2.dot(r, r)); // #ffffffff
                    col = laz.Vec3.lerp(col, vec3fromHexWithAlpha(0x832121ff), laz.Vec2.dot(q, q)); // #832121ff
                    // col = laz.Vec3.lerp(col, vec3fromHexWithAlpha(0x0adaffff), 0.5 * q.y * q.y); // #0adaffff
                    col = laz.Vec3.lerp(
                        col,
                        vec3fromHexWithAlpha(0x290202ff), // #290202ff
                        0.5 * supersmoothstep(1.1, 1.3, @abs(r.x) + @abs(r.y)),
                    );

                    // Add a lighting
                    const e = 1.0 / scale;
                    const fex, _, _ = pattern3(.{ .x = x + e, .y = y });
                    const fey, _, _ = pattern3(.{ .x = x, .y = y + e });

                    // compute surface normal
                    // normal.x is the derivative of pattern3 along x
                    // normal.y is the derivative of pattern3 along y
                    // normal.z is the step
                    const normal = laz.Vec3.normalize(.{ .x = fex - f, .y = fey - f, .z = e });

                    // we define a light direction
                    const lig = laz.Vec3.normalize(.{ .x = 0.5, .y = -0.3, .z = -0.1 });
                    // we compute the diffuse term
                    const diff = std.math.clamp(0.5 + 0.9 * laz.Vec3.dot(normal, lig), 0.0, 1.0);
                    const lin: laz.Vec3 = .{
                        .x = (normal.z * 0.2 + 0.7) + 0.1 * diff,
                        .y = (normal.z * 0.2 + 0.7) + 0.1 * diff,
                        .z = (normal.z * 0.2 + 0.7) + 0.1 * diff,
                    };
                    col = .{ .x = col.x * lin.x, .y = col.y * lin.y, .z = col.z * lin.z };

                    // increase contrast on high frequency details
                    col = laz.Vec3.mul1(col, f * 2.0);

                    // inverse value and apply a gamma curve to boost contrast
                    const functor = struct {
                        pub fn call(value: f32) f32 {
                            return std.math.pow(f32, 1 - value, 3.0);
                        }
                    }.call;
                    col = forEach3(col, functor);
                    break :blk .{ col.x, col.y, col.z };
                },
            };
            data.items[i * width * 3 + j * 3 + 0] = @as(u8, @intFromFloat(std.math.clamp(r * 255, 0, 255)));
            data.items[i * width * 3 + j * 3 + 1] = @as(u8, @intFromFloat(std.math.clamp(g * 255, 0, 255)));
            data.items[i * width * 3 + j * 3 + 2] = @as(u8, @intFromFloat(std.math.clamp(b * 255, 0, 255)));
        }
    }

    return data;
}

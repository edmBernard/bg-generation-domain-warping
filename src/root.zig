//! Simplex noise and fbm implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
const std = @import("std");
pub const PatternType = @import("types").PatternType;

const time = 126.0;

const Vec2 = struct {
    x: f32,
    y: f32,
};
const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn fromHexWithAlpha(hex: u32) Vec3 {
        return .{
            .x = @as(f32, @floatFromInt((hex & 0xFF000000) >> 24)) / 255.0,
            .y = @as(f32, @floatFromInt((hex & 0x00FF0000) >> 16)) / 255.0,
            .z = @as(f32, @floatFromInt((hex & 0x0000FF00) >> 8)) / 255.0,
        };
    }
};

inline fn mul(a: Vec2, b: f32) Vec2 {
    return .{
        .x = a.x * b,
        .y = a.y * b,
    };
}

inline fn matmul(m: [4]f32, b: Vec2) Vec2 {
    return .{
        .x = m[0] * b.x + m[1] * b.y,
        .y = m[2] * b.x + m[3] * b.y,
    };
}
inline fn add(a: Vec2, b: f32) Vec2 {
    return .{
        .x = a.x + b,
        .y = a.y + b,
    };
}
inline fn add3(a: Vec3, b: f32) Vec3 {
    return .{
        .x = a.x + b,
        .y = a.y + b,
        .z = a.z + b,
    };
}

inline fn lerp3(a: Vec3, b: Vec3, t: f32) Vec3 {
    return .{
        .x = std.math.lerp(a.x, b.x, t),
        .y = std.math.lerp(a.y, b.y, t),
        .z = std.math.lerp(a.z, b.z, t),
    };
}

inline fn forEach3(a: Vec3, fnc: fn (f32) f32) Vec3 {
    return .{
        .x = fnc(a.x),
        .y = fnc(a.y),
        .z = fnc(a.z),
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
    return dot3(n, .{ .x = 70, .y = 70, .z = 70 });
}

// rotation matrix to avoid direction artifacts
const angle = std.math.pi / 3.0;
const mtx = [4]f32{ @cos(angle), @sin(angle), -@sin(angle), @cos(angle) };

// fbm noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
fn fbm(comptime octaves: i32, vec: Vec2) f32 {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 1.0; // change a lot the visual aspect
    const G = std.math.exp2(-H);
    // f = 1.0 f*= 2.01; nice
    // f = 2.0 f*= 1.01; nice
    var f: f32 = 1.0;
    var a: f32 = 1.0;
    var t: f32 = 0.0;
    for (0..octaves) |_| {
        t += a * noise(mul(matmul(mtx, vec), f));
        f *= 2.01;
        a *= G;
    }
    return t;
}

fn pattern1(p: Vec2) f32 {
    return fbm(6, p);
}

fn pattern2(p: Vec2) struct { f32, Vec2 } {
    const q: Vec2 = .{
        .x = fbm(6, .{ .x = p.x + 0, .y = p.y + 0 }),
        .y = fbm(6, .{ .x = p.x + 5.2, .y = p.y + 1.3 }),
    };

    return .{ fbm(6, .{
        .x = p.x + 4.0 * q.x,
        .y = p.y + 4.0 * q.y,
    }), q };
}

fn pattern3(p: Vec2) struct { f32, Vec2, Vec2 } {
    const q: Vec2 = .{
        .x = fbm(6, .{ .x = p.x + 0, .y = p.y + 0 }),
        .y = fbm(6, .{ .x = p.x + 5.2, .y = p.y + 1.3 }),
    };

    const r: Vec2 = .{
        .x = fbm(4, .{ .x = p.x + 2.1 * q.x + 1.7, .y = p.y + 2.1 * q.y + 9.2 }),
        .y = fbm(4, .{ .x = p.x + 2.1 * q.x + 8.3, .y = p.y + 2.1 * q.y + 2.8 }),
    };

    return .{ fbm(4, .{
        .x = p.x + 2.1 * r.x,
        .y = p.y + 2.1 * r.y,
    }), q, r };
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
                    var col = Vec3.fromHexWithAlpha(0xd88314ff); // #d88314ff
                    col = lerp3(col, Vec3.fromHexWithAlpha(0x4c402fff), f); // #4c402fff
                    col = lerp3(col, Vec3.fromHexWithAlpha(0x760404ff), dot2(q, q)); // #760404ff
                    const functor = struct {
                        pub fn call(value: f32) f32 {
                            return value * value;
                        }
                    }.call;
                    col = forEach3(col, functor);
                    break :blk .{ col.x, col.y, col.z };
                },
                PatternType.k3 => blk: {
                    const f, const q, const r = pattern3(.{ .x = x, .y = y });
                    var col = Vec3.fromHexWithAlpha(0x333facff); // #333facff

                    col = lerp3(col, Vec3.fromHexWithAlpha(0x000000ff), f); // #000000ff
                    col = lerp3(col, Vec3.fromHexWithAlpha(0x1ca1e9ff), dot2(r, r)); // #1ca1e9ff
                    col = lerp3(col, Vec3.fromHexWithAlpha(0x0adaffff), dot2(q, q)); // #0adaffff

                    const functor = struct {
                        pub fn call(value: f32) f32 {
                            return value * value;
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

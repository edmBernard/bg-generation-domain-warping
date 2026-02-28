//! Simplex noise and fbm implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
//! This variant uses 3D Simplex noise with time as the Z dimension for in-place evolution.
const std = @import("std");

const laz = @import("linearalgebra.zig");
const simplex = @import("simplex.zig");
const zpp = @import("zpp");

const VecU8 = @Vector(laz.vec_len, u8);

/// The hex color is in format 0xRRGGBBAA
inline fn hexToVec3(comptime hex: u32) laz.Vec3 {
    return .{
        .x = laz.toV(@as(f32, @floatFromInt((hex & 0xFF000000) >> 24)) / 255.0),
        .y = laz.toV(@as(f32, @floatFromInt((hex & 0x00FF0000) >> 16)) / 255.0),
        .z = laz.toV(@as(f32, @floatFromInt((hex & 0x0000FF00) >> 8)) / 255.0),
    };
}

// 3D rotation matrix for FBM octave decorrelation
// Compose Rz(pi/4) and Rx(pi/6)
const cos_z = @cos(std.math.pi / 4.0);
const sin_z = @sin(std.math.pi / 4.0);
const cos_x = @cos(std.math.pi / 6.0);
const sin_x = @sin(std.math.pi / 6.0);

// Rz(pi/4) * Rx(pi/6):
// | cos_z  -sin_z*cos_x  sin_z*sin_x |
// | sin_z   cos_z*cos_x -cos_z*sin_x |
// |  0      sin_x         cos_x       |
const mtx3 = laz.Mat3x3{
    .data = [9]laz.InnerType{
        @splat(cos_z),         @splat(-sin_z * cos_x), @splat(sin_z * sin_x),
        @splat(sin_z),         @splat(cos_z * cos_x),  @splat(-cos_z * sin_x),
        @splat(@as(f32, 0.0)), @splat(sin_x),          @splat(cos_x),
    },
};

/// fractional Brownian motion (fBm) using 3D Simplex noise
fn fbm3d(comptime octaves: i32, vec: laz.Vec3) laz.InnerType {
    const H = 1.0;
    const G = laz.toV(std.math.exp2(-H));
    var f = laz.toV(1.0);
    var a = laz.toV(0.5);
    var t = laz.toV(0.0);
    var p = vec;
    inline for (0..octaves) |_| {
        t += a * simplex.noise3d(.{
            .x = p.x * f,
            .y = p.y * f,
            .z = p.z * f,
        });
        p = mtx3.mulvec3(p);
        f *= laz.toV(1.9);
        a *= G;
    }
    return t;
}

fn pattern(p: laz.Vec3) struct { laz.InnerType, laz.Vec2, laz.Vec2 } {
    // low frequency
    const q: laz.Vec2 = .{
        .x = laz.toV(0.5) + laz.toV(0.5) * fbm3d(8, .{ .x = p.x + laz.toV(1.1), .y = p.y + laz.toV(0.1), .z = p.z }),
        .y = laz.toV(0.5) + laz.toV(0.5) * fbm3d(8, .{ .x = p.x + laz.toV(5.1), .y = p.y + laz.toV(1.5), .z = p.z }),
    };

    // mid frequency
    const r: laz.Vec2 = .{
        .x = laz.toV(0.5) - laz.toV(0.5) * fbm3d(6, .{ .x = p.x + laz.toV(6.1) * q.x, .y = p.y + laz.toV(6.1) * q.y, .z = p.z }),
        .y = laz.toV(0.5) - laz.toV(0.5) * fbm3d(6, .{ .x = p.x + laz.toV(6.1) * q.x, .y = p.y + laz.toV(6.1) * q.y, .z = p.z }),
    };

    // high frequency
    const r_scaled: laz.Vec2 = r.mul1(laz.toV(8.1));
    const f = laz.toV(0.5) + laz.toV(0.5) * fbm3d(10, .{
        .x = p.x + r_scaled.x,
        .y = p.y + r_scaled.y,
        .z = p.z,
    });
    return .{ f, r, q };
}

const ProcessingFunctor = struct {
    scale: laz.InnerType,
    time: laz.InnerType,

    pub inline fn process(ctx: ProcessingFunctor, x: laz.InnerType, y: laz.InnerType) [3]VecU8 {
        const xs = x / ctx.scale;
        const ys = y / ctx.scale;

        // Compute base pattern with time as Z dimension
        const f, const r, const q = pattern(.{ .x = xs, .y = ys, .z = ctx.time * laz.toV(0.1) });

        // Compute color of the pattern
        var col = hexToVec3(0x561111ff);
        col = col.lerp(hexToVec3(0xe2730cff), f);
        col = col.lerp(hexToVec3(0xffffffff), laz.Vec2.dot(r, r));
        col = col.lerp(hexToVec3(0x832121ff), laz.Vec2.dot(q, q));

        col = col.lerp(
            hexToVec3(0x290202ff),
            laz.toV(0.5) * laz.smoothstep(laz.toV(1.1), laz.toV(1.3), @abs(r.x) + @abs(r.y)),
        );

        // Increase contrast on high frequency details
        col = col.mul1(f * laz.toV(2.0));

        // Inverse value and apply a gamma curve to boost contrast
        const temp = laz.Vec3.ones().sub(col);
        col = temp.pow(3);

        // Convert from [0, 1] float to [0, 255] u8
        const splat_0: laz.InnerType = @splat(0.0);
        const splat_255: laz.InnerType = @splat(255.0);
        return .{
            @intFromFloat(@max(splat_0, @min(splat_255, col.x * splat_255))),
            @intFromFloat(@max(splat_0, @min(splat_255, col.y * splat_255))),
            @intFromFloat(@max(splat_0, @min(splat_255, col.z * splat_255))),
        };
    }
};

/// Generate an image of given width and height using domain warping and fbm noise
pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32, time: f32) !std.ArrayList(u8) {
    var data: std.ArrayList(u8) = .empty;
    try data.appendNTimes(allocator, 0, width * height * 3);

    const scale = laz.toV(1000.0);
    const time_splat: laz.InnerType = @splat(time);

    const context = ProcessingFunctor{
        .scale = scale,
        .time = time_splat,
    };

    const region = zpp.Region{ .x = 0, .y = 0, .width = width, .height = height };
    const destination = zpp.makeInterleavedDest(u8, 3, data.items, width, region);
    const generator = zpp.generate(laz.InnerType, context, ProcessingFunctor.process);
    zpp.process(generator, destination);

    return data;
}

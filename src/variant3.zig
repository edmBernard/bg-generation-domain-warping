//! Simplex noise and fbm implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
//! This variant uses 3D Simplex noise with time as the Z dimension for in-place evolution.
const std = @import("std");
const zpp = @import("zpp");

const simplex = @import("simplex.zig");
const color = @import("color.zig");

const working_type = @import("working_type.zig");
const u8v = working_type.u8v;
const f32v = working_type.f32v;
const laf = zpp.zla.with(f32v);

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
const mtx3 = laf.Mat3x3{
    .data = [9]f32v{
        @splat(cos_z), @splat(-sin_z * cos_x), @splat(sin_z * sin_x),
        @splat(sin_z), @splat(cos_z * cos_x),  @splat(-cos_z * sin_x),
        @splat(0.0),   @splat(sin_x),          @splat(cos_x),
    },
};

/// fractional Brownian motion (fBm) using 3D Simplex noise
fn fbm3d(comptime octaves: i32, vec: laf.Vec3) f32v {
    const H = 1.0;
    const G = laf.splat(std.math.exp2(-H));
    var f = laf.splat(1.0);
    var a = laf.splat(0.5);
    var t = laf.splat(0.0);
    var p = vec;
    inline for (0..octaves) |_| {
        t += a * simplex.noise3d(.{
            .x = p.x * f,
            .y = p.y * f,
            .z = p.z * f,
        });
        p = mtx3.mulvec(p);
        f *= laf.splat(1.9);
        a *= G;
    }
    return t;
}

fn pattern(p: laf.Vec3) struct { f32v, laf.Vec2, laf.Vec2 } {
    // low frequency
    const q: laf.Vec2 = .{
        .x = laf.splat(0.5) + laf.splat(0.5) * fbm3d(8, .{ .x = p.x + laf.splat(1.1), .y = p.y + laf.splat(0.1), .z = p.z }),
        .y = laf.splat(0.5) + laf.splat(0.5) * fbm3d(8, .{ .x = p.x + laf.splat(5.1), .y = p.y + laf.splat(1.5), .z = p.z }),
    };

    // mid frequency
    const r: laf.Vec2 = .{
        .x = laf.splat(0.5) - laf.splat(0.5) * fbm3d(6, .{ .x = p.x + laf.splat(6.1) * q.x, .y = p.y + laf.splat(6.1) * q.y, .z = p.z }),
        .y = laf.splat(0.5) - laf.splat(0.5) * fbm3d(6, .{ .x = p.x + laf.splat(6.1) * q.x, .y = p.y + laf.splat(6.1) * q.y, .z = p.z }),
    };

    // high frequency
    const r_scaled: laf.Vec2 = r.mul1(laf.splat(8.1));
    const f = laf.splat(0.5) + laf.splat(0.5) * fbm3d(10, .{
        .x = p.x + r_scaled.x,
        .y = p.y + r_scaled.y,
        .z = p.z,
    });
    return .{ f, r, q };
}

const ProcessingFunctor = struct {
    scale: f32v,
    time: f32v,

    pub inline fn process(ctx: ProcessingFunctor, x: f32v, y: f32v) [3]u8v {
        const xs = x / ctx.scale;
        const ys = y / ctx.scale;

        // Compute base pattern with time as Z dimension
        const f, const r, const q = pattern(.{ .x = xs, .y = ys, .z = ctx.time * laf.splat(0.1) });

        // Compute color of the pattern
        var col = color.hexToVec3(0x561111ff);
        col = col.lerp(color.hexToVec3(0xe2730cff), f);
        col = col.lerp(color.hexToVec3(0xffffffff), r.dot(r));
        col = col.lerp(color.hexToVec3(0x832121ff), q.dot(q));

        col = col.lerp(
            color.hexToVec3(0x290202ff),
            laf.splat(0.5) * zpp.math.smoothstep(laf.splat(1.1), laf.splat(1.3), @abs(r.x) + @abs(r.y)),
        );

        // Increase contrast on high frequency details
        col = col.mul1(f * laf.splat(2.0));

        // Inverse value and apply a gamma curve to boost contrast
        const temp = laf.Vec3.ones.sub(col);
        col = temp.pow(3);

        // Convert from [0, 1] float to [0, 255] u8
        const zero: f32v = @splat(0.0);
        const max8u: f32v = @splat(255.0);
        return .{
            @intFromFloat(@max(zero, @min(max8u, col.x * max8u))),
            @intFromFloat(@max(zero, @min(max8u, col.y * max8u))),
            @intFromFloat(@max(zero, @min(max8u, col.z * max8u))),
        };
    }
};

/// Generate an image of given width and height using domain warping and fbm noise
pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32, time: f32) !std.ArrayList(u8) {
    var data: std.ArrayList(u8) = .empty;
    try data.appendNTimes(allocator, 0, width * height * 3);

    const scale = laf.splat(1000.0);
    const time_splat: f32v = @splat(time);

    const context = ProcessingFunctor{
        .scale = scale,
        .time = time_splat,
    };

    const region = zpp.Region{ .x = 0, .y = 0, .width = width, .height = height };
    const destination = zpp.makeInterleavedDest(u8, 3, data.items, width, region);
    const generator = zpp.generate(f32v, context, ProcessingFunctor.process);
    zpp.process(generator, destination);

    return data;
}

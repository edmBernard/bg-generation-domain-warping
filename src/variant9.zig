//! Perlin noise and fbm implementation
const std = @import("std");
const zpp = @import("zpp");

const simplex = @import("simplex.zig");
const color = @import("color.zig");

const working_type = @import("working_type.zig");
const u8v = working_type.u8v;
const f32v = working_type.f32v;
const laf = zpp.zla.With(f32v);

// 3D rotation matrix for FBM octave decorrelation
// Compose Rz(pi/4) and Rx(pi/7)
const cos_z = @cos(std.math.pi / 4.0);
const sin_z = @sin(std.math.pi / 4.0);
const cos_x = @cos(std.math.pi / 7.0);
const sin_x = @sin(std.math.pi / 7.0);

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
/// https://en.wikipedia.org/wiki/Fractional_Brownian_motion
fn fbm3d(comptime octaves: i32, vec: laf.Vec3) f32v {
    const H = 0.5;
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

fn pattern(p: laf.Vec3) laf.InnerType {
    // We compute one fbm per axis to avoid directional artifacts.
    // low frequency
    const q: laf.Vec2 = .{
        .x = fbm3d(14, .{
            .x = p.x * laf.splat(1.0) + laf.splat(15.0),
            .y = p.y * laf.splat(1.0) + laf.splat(6.0),
            .z = p.z,
        }),
        .y = fbm3d(14, .{
            .x = p.x * laf.splat(1.0) + laf.splat(5.2),
            .y = p.y * laf.splat(1.0) + laf.splat(1.3),
            .z = p.z + laf.splat(2.7),
        }),
    };

    // mid frequency
    const r: laf.Vec2 = .{
        .x = fbm3d(14, .{
            .x = (p.x + q.x) * laf.splat(0.6) + laf.splat(0.3),
            .y = (p.y + q.y) * laf.splat(0.6) + laf.splat(0.6),
            .z = p.z,
        }),
        .y = fbm3d(14, .{
            .x = (p.x + q.x) * laf.splat(0.6) + laf.splat(4.1),
            .y = (p.y + q.y) * laf.splat(0.6) + laf.splat(2.8),
            .z = p.z + laf.splat(3.4),
        }),
    };

    // high frequency
    const f = fbm3d(14, .{
        .x = (p.x + r.x) * laf.splat(2.6) - laf.splat(0.6),
        .y = (p.y + r.y) * laf.splat(2.6) - laf.splat(0.4),
        .z = p.z,
    });
    return f;
}

// I'm not really sure this processing function make the code more readable
// We pass this functor to the pixel processor that will call it for each pixel line
const ProcessingFunctor = struct {
    scale: f32v,
    time: f32v,

    pub inline fn process(ctx: ProcessingFunctor, x: f32v, y: f32v) [3]u8v {
        const xs = x / ctx.scale;
        const ys = y / ctx.scale;

        // Compute base pattern
        // f represents the intensity of the pattern high frequency details
        const f = pattern(.{ .x = xs, .y = ys, .z = ctx.time * laf.splat(0.1) });
        const value = f;

        // Compute color of the pattern
        // We basically mix several colors depending on the pattern values
        const white = color.hexToVec3(0xffffffff); // #ffffffff
        const dark_blue = color.hexToVec3(0x00193cff); // #00193cff
        const col = white.mul1(value).add(dark_blue);

        // Convert from [0, 1] float to [0, 255] u8
        const splat_0: f32v = @splat(0.0);
        const splat_255: f32v = @splat(255.0);
        return .{
            @trunc(@max(splat_0, @min(splat_255, col.x * splat_255))),
            @trunc(@max(splat_0, @min(splat_255, col.y * splat_255))),
            @trunc(@max(splat_0, @min(splat_255, col.z * splat_255))),
        };
    }
};

/// Generate an image of given width and height using domain warping and fbm noise
/// The code is a bit long and hard to read mainly because it use simd operations to speed up processing
pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32, time: f32) !std.ArrayList(u8) {
    var data: std.ArrayList(u8) = .empty;
    try data.appendNTimes(allocator, 0, width * height * 3);

    const scale = laf.splat(1000.0);
    const time_splat: laf.InnerType = @splat(time + 10.0);

    const context = ProcessingFunctor{
        .scale = scale,
        .time = time_splat,
    };

    const region = zpp.Region{ .x = 0, .y = 0, .width = width, .height = height };
    const destination = try zpp.makeInterleavedDest(u8, 3, data.items, width, region);
    const generator = zpp.generate(laf.InnerType, context, ProcessingFunctor.process);
    zpp.process(generator, destination);

    return data;
}

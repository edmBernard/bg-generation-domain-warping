//! Perlin noise and fbm implementation
const std = @import("std");
const zpp = @import("zpp");

const simplex = @import("simplex.zig");
const color = @import("color.zig");

const working_type = @import("working_type.zig");
const u8v = working_type.u8v;
const f32v = working_type.f32v;
const laf = zpp.zla.with(f32v);

// rotation matrix to avoid direction artifacts
const angle = std.math.pi / 4.0;
const mtx = laf.Mat2x2{
    .data = [4]f32v{
        @splat(@cos(angle)),
        @splat(@sin(angle)),
        @splat(-@sin(angle)),
        @splat(@cos(angle)),
    },
};

/// fractional Brownian motion (fBm), also called a fractal Brownian motion
/// https://en.wikipedia.org/wiki/Fractional_Brownian_motion
fn fbm(comptime octaves: i32, vec: laf.Vec2) f32v {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 0.5; // change a lot the visual aspect
    const G = laf.splat(std.math.exp(-H));
    var f = laf.splat(1.0);
    var a = laf.splat(0.5);
    var t = laf.splat(0.0);
    var p = vec;
    inline for (0..octaves) |_| {
        // p = mtx.mulvec(p);
        t += a * simplex.noise(p.sub1(@splat(1.0)).mul1(f));
        f *= laf.splat(1.9);
        a *= G;
    }
    return t;
}

fn pattern(p: laf.Vec2) laf.InnerType {
    // low frequency
    const q_offset: laf.Vec2 = .{ .x = @splat(5), .y = @splat(6) };
    const q = fbm(14, p.mul1(@splat(6.0)).add(q_offset));

    // mid frequency
    const r_offset: laf.Vec2 = .{ .x = @splat(0.3), .y = @splat(0.6) };
    const r = fbm(14, p.add1(q).mul1(@splat(0.6)).add(r_offset));

    // high frequency
    const f_offset: laf.Vec2 = .{ .x = @splat(-0.6), .y = @splat(-0.4) };
    const f = fbm(14, p.add1(r).mul1(@splat(2.6)).add(f_offset));
    return f;
}

// I'm not really sure this processing function make the code more readable
// We pass this functor to the pixel processor that will call it for each pixel line
const ProcessingFunctor = struct {
    scale: f32v,
    sin_time: f32v,

    pub inline fn process(ctx: ProcessingFunctor, x: f32v, y: f32v) [3]u8v {
        const xs = x / ctx.scale + ctx.sin_time;
        const ys = y / ctx.scale + ctx.sin_time;

        // Compute base pattern
        // f represents the intensity of the pattern high frequency details
        const f = pattern(.{ .x = xs, .y = ys });
        const value = f;

        // Compute color of the pattern
        // We basically mix several colors depending on the pattern values
        const gray = color.hexToVec3(0x808080ff); // #808080ff
        const white = color.hexToVec3(0xffffffff); // #ffffffff
        const dark_blue = color.hexToVec3(0x00193cff); // #00193cff
        const dark_orange = color.hexToVec3(0x734023ff); // #734023ff
        var col = white.mul1(value).add(dark_blue).mul1(laf.splat(std.math.pi * 2));
        col = .{
            .x = @cos(col.x),
            .y = @cos(col.y),
            .z = @cos(col.z),
        };
        col = col.mul(dark_orange).add(gray);
        col = col.pow(2);

        // Convert from [0, 1] float to [0, 255] u8
        const splat_0: f32v = @splat(0.0);
        const splat_255: f32v = @splat(255.0);
        return .{
            @intFromFloat(@max(splat_0, @min(splat_255, col.x * splat_255))),
            @intFromFloat(@max(splat_0, @min(splat_255, col.y * splat_255))),
            @intFromFloat(@max(splat_0, @min(splat_255, col.z * splat_255))),
        };
    }
};

/// Generate an image of given width and height using domain warping and fbm noise
/// The code is a bit long and hard to read mainly because it use simd operations to speed up processing
pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32, time: f32) !std.ArrayList(u8) {
    var data: std.ArrayList(u8) = .empty;
    try data.appendNTimes(allocator, 0, width * height * 3);

    const scale = laf.splat(10000.0);
    const sin_time: laf.InnerType = @splat(@sin(time));

    const context = ProcessingFunctor{
        .scale = scale,
        .sin_time = sin_time,
    };

    const region = zpp.Region{ .x = 0, .y = 0, .width = width, .height = height };
    const destination = zpp.makeInterleavedDest(u8, 3, data.items, width, region);
    const generator = zpp.generate(laf.InnerType, context, ProcessingFunctor.process);
    zpp.process(generator, destination);

    return data;
}

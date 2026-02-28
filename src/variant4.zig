//! Perlin noise and fbm implementation
const std = @import("std");
const zpp = @import("zpp");

const perlin = @import("perlin.zig");
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
/// fbm noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
fn fbm(comptime octaves: i32, vec: laf.Vec2) f32v {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 1.0; // change a lot the visual aspect
    const G = laf.splat(std.math.exp2(-H));
    var f = laf.splat(1.0);
    var a = laf.splat(0.5);
    var t = laf.splat(0.0);
    inline for (0..octaves) |_| {
        t += a * perlin.noise_gradient(mtx.mulvec(vec).mul1(f));
        f *= laf.splat(1.9);
        a *= G;
    }
    return t;
}

fn pattern(p: laf.Vec2) struct { laf.InnerType, laf.Vec2, laf.Vec2 } {
    // low frequency
    const q: laf.Vec2 = .{
        .x = laf.splat(0.5) + laf.splat(0.5) * fbm(8, .{ .x = p.x + laf.splat(1.1), .y = p.y + laf.splat(0.1) }),
        .y = laf.splat(0.5) + laf.splat(0.5) * fbm(8, .{ .x = p.x + laf.splat(5.1), .y = p.y + laf.splat(1.5) }),
    };

    // mid frequency
    const r: laf.Vec2 = .{
        .x = laf.splat(0.5) - laf.splat(0.5) * fbm(6, .{ .x = p.x + laf.splat(6.1) * q.x, .y = p.y + laf.splat(6.1) * q.y }),
        .y = laf.splat(0.5) - laf.splat(0.5) * fbm(6, .{ .x = p.x + laf.splat(6.1) * q.x, .y = p.y + laf.splat(6.1) * q.y }),
    };

    // high frequency
    const f = laf.splat(0.5) + laf.splat(0.5) * fbm(10, p.add(r.mul1(laf.splat(8.1))));
    return .{ f, r, q };
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
        // r are the mid frequency details
        // q are the low frequency details
        const f, const r, const q = pattern(.{ .x = xs, .y = ys });

        // Compute color of the pattern
        // We basically mix several colors depending on the pattern values
        // Be carefull we do a color inversion at the end.
        // So color are redish here but will produce blueish result later.
        var col = color.hexToVec3(0x561111ff); // #561111ff
        col = col.lerp(color.hexToVec3(0xe2730cff), f); // #e2730cff
        col = col.lerp(color.hexToVec3(0xffffffff), r.dot(r)); // #ffffffff
        col = col.lerp(color.hexToVec3(0x832121ff), q.dot(q)); // #832121ff

        // This extra step add extra color in black area
        col = col.lerp(
            color.hexToVec3(0x290202ff), // #290202ff
            laf.splat(0.5) * zpp.math.smoothstep(laf.splat(1.1), laf.splat(1.3), @abs(r.x) + @abs(r.y)),
        );

        // Increase contrast on high frequency details
        col = col.mul1(f * laf.splat(2.0));

        // Inverse value and apply a gamma curve to boost contrast
        // std.math.pow is not vectorized so we do it manually
        const temp = laf.Vec3.ones.sub(col);
        col = temp.pow(3); // gamma like

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

    const scale = laf.splat(400.0);
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

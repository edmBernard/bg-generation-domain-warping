//! Simplex noise and fbm implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
const std = @import("std");
const laz = @import("linearalgebra");
const simplex = @import("simplex");
const ppz = @import("pixel_processor");

/// The hex color is in format 0xRRGGBBAA
inline fn hexToVec3(comptime hex: u32) laz.Vec3 {
    return .{
        .x = laz.toV(@as(f32, @floatFromInt((hex & 0xFF000000) >> 24)) / 255.0),
        .y = laz.toV(@as(f32, @floatFromInt((hex & 0x00FF0000) >> 16)) / 255.0),
        .z = laz.toV(@as(f32, @floatFromInt((hex & 0x0000FF00) >> 8)) / 255.0),
    };
}

// rotation matrix to avoid direction artifacts
// This is expecially true with perlin noise (we can see directional artifacts)
const angle = std.math.pi / 4.0;
const mtx = laz.Mat2x2{
    .data = [4]laz.InnerType{
        @splat(@cos(angle)),
        @splat(@sin(angle)),
        @splat(-@sin(angle)),
        @splat(@cos(angle)),
    },
};

/// fractional Brownian motion (fBm), also called a fractal Brownian motion
/// https://en.wikipedia.org/wiki/Fractional_Brownian_motion
/// fbm noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
fn fbm(comptime octaves: i32, vec: laz.Vec2) laz.InnerType {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 1.0; // change a lot the visual aspect
    const G = laz.toV(std.math.exp2(-H));
    var f = laz.toV(1.0);
    var a = laz.toV(0.5);
    var t = laz.toV(0.0);
    inline for (0..octaves) |_| {
        t += a * simplex.noise(mtx.mulvec2(vec).mul1(f));
        f *= laz.toV(1.9);
        a *= G;
    }
    return t;
}

/// Same as above but tuned differently
fn fbm6(vec: laz.Vec2) laz.InnerType {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 1.0; // change a lot the visual aspect
    const G = laz.toV(std.math.exp2(-H));
    var f = laz.toV(1.0);
    var a = laz.toV(0.5);
    var t = laz.toV(0.0);
    inline for (0..6) |_| {
        t += a * simplex.noise(mtx.mulvec2(vec).mul1(f));
        f *= laz.toV(2.1);
        a *= G;
    }
    return t * laz.toV(1.1);
}

fn pattern(p: laz.Vec2) struct { laz.InnerType, laz.Vec2, laz.Vec2 } {
    // low frequency
    const q: laz.Vec2 = .{
        .x = laz.toV(0.5) + laz.toV(0.5) * fbm(4, .{ .x = p.x + laz.toV(1.1), .y = p.y + laz.toV(0.1) }),
        .y = laz.toV(0.5) + laz.toV(0.5) * fbm(4, .{ .x = p.x + laz.toV(5.1), .y = p.y + laz.toV(1.5) }),
    };

    // mid frequency
    const r: laz.Vec2 = .{
        .x = laz.toV(0.5) - laz.toV(0.5) * fbm6(.{ .x = p.x + laz.toV(4.1) * q.x, .y = p.y + laz.toV(4.1) * q.y }),
        .y = laz.toV(0.5) - laz.toV(0.5) * fbm6(.{ .x = p.x + laz.toV(4.1) * q.x, .y = p.y + laz.toV(4.1) * q.y }),
    };

    // high frequency
    const f = laz.toV(0.5) + laz.toV(0.5) * fbm(4, p.add(r.mul1(laz.toV(2.1))));
    return .{ f, r, q };
}

// I'm not really sure this processing function make the code more readable
// We pass this functor to the pixel processor that will call it for each pixel line
const ProcessingFunctor = struct {
    scale: laz.InnerType,
    sin_time: laz.InnerType,

    pub inline fn process(ctx: ProcessingFunctor, x: anytype, y: anytype) [3]laz.InnerType {
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
        var col = hexToVec3(0x561111ff); // #561111ff
        col = col.lerp(hexToVec3(0xe2730cff), f); // #e2730cff
        col = col.lerp(hexToVec3(0xffffffff), laz.Vec2.dot(r, r)); // #ffffffff
        col = col.lerp(hexToVec3(0x832121ff), laz.Vec2.dot(q, q)); // #832121ff

        // This extra step add extra color in black area
        col = col.lerp(
            hexToVec3(0x290202ff), // #290202ff
            laz.toV(0.5) * laz.smoothstep(laz.toV(1.1), laz.toV(1.3), @abs(r.x) + @abs(r.y)),
        );

        // After the main color is compute we add some lighting to add extra small details.
        // Compute derivative of the pattern : df/dx and df/dy using finite difference
        // It should be possible to compute the derivative analytically
        // because 2/3 of the computation is for this derivative
        const e = laz.toV(1.0) / ctx.scale;
        const fex, _, _ = pattern(.{ .x = xs + e, .y = ys });
        const fey, _, _ = pattern(.{ .x = xs, .y = ys + e });

        // compute surface normal
        // normal.x is the derivative of pattern along x
        // normal.y is the derivative of pattern along y
        // normal.z is the step
        const normal = laz.Vec3.normalize(.{ .x = fex - f, .y = fey - f, .z = e });

        // we define a light direction
        const light = laz.Vec3.normalize(.{ .x = laz.toV(0.5), .y = laz.toV(-0.3), .z = laz.toV(-0.1) });
        // we compute the diffuse term
        const diff = std.math.clamp(laz.toV(0.5) + laz.toV(0.9) * laz.Vec3.dot(normal, light), laz.toV(0.0), laz.toV(1.0));
        const lin: laz.Vec3 = .{
            .x = (normal.z * laz.toV(0.2) + laz.toV(0.7)) + laz.toV(0.1) * diff,
            .y = (normal.z * laz.toV(0.2) + laz.toV(0.7)) + laz.toV(0.1) * diff,
            .z = (normal.z * laz.toV(0.2) + laz.toV(0.7)) + laz.toV(0.1) * diff,
        };
        col = col.mul(lin);

        // Increase contrast on high frequency details
        col = col.mul1(f * laz.toV(2.0));

        // Inverse value and apply a gamma curve to boost contrast
        // std.math.pow is not vectorized so we do it manually
        const temp = laz.Vec3.ones().sub(col);
        col = temp.pow(3); // gamma like

        return .{ col.x, col.y, col.z };
    }
};

/// Generate an image of given width and height using domain warping and fbm noise
/// The code is a bit long and hard to read mainly because it use simd operations to speed up processing
pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32) !std.ArrayList(u8) {
    var data: std.ArrayList(u8) = .empty;
    try data.appendNTimes(allocator, 0, width * height * 3);

    // Variable to simulate time and allow to select a different variation of the pattern
    const time = 125.0;

    const scale = laz.toV(1000.0);
    const sin_time = laz.toV(std.math.sin(time));

    const context = ProcessingFunctor{
        .scale = scale,
        .sin_time = sin_time,
    };

    // This call hide the complexity of the pixel processing using simd operations
    // It will call ProcessingFunctor.process for each "pixel"/"simd line"
    ppz.process(&data.items, width, height, context, ProcessingFunctor.process);

    return data;
}

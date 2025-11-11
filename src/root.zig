//! Simplex noise and fbm implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
const std = @import("std");

const vec_len = std.simd.suggestVectorLength(u8) orelse @panic("No SIMD?");
const Real: type = @Vector(vec_len, f32);

const laz = @import("linearalgebra").as(Real);
const simplex = @import("simplex").as(Real);

/// The hex color is in format 0xRRGGBBAA
inline fn hexToVec3(comptime hex: u32) laz.Vec3 {
    return .{
        .x = laz.toS(@as(f32, @floatFromInt((hex & 0xFF000000) >> 24)) / 255.0),
        .y = laz.toS(@as(f32, @floatFromInt((hex & 0x00FF0000) >> 16)) / 255.0),
        .z = laz.toS(@as(f32, @floatFromInt((hex & 0x0000FF00) >> 8)) / 255.0),
    };
}

/// Perform Hermite interpolation between two values
inline fn smoothstep(edge0: Real, edge1: Real, x: Real) Real {
    const t = std.math.clamp((x - edge0) / (edge1 - edge0), laz.toS(0.0), laz.toS(1.0));
    return t * t * (laz.toS(3.0) - laz.toS(2.0) * t);
}

/// Perform Quintic interpolation between two values
inline fn supersmoothstep(edge0: Real, edge1: Real, x: Real) Real {
    const t = std.math.clamp((x - edge0) / (edge1 - edge0), laz.toS(0.0), laz.toS(1.0));
    return t * t * t * (laz.toS(10.0) - laz.toS(15.0) * t + laz.toS(6.0) * t * t);
}

// rotation matrix to avoid direction artifacts
const angle = std.math.pi / 4.0;
const mtx = laz.Mat2x2{
    .data = [4]Real{
        @splat(@cos(angle)),
        @splat(@sin(angle)),
        @splat(-@sin(angle)),
        @splat(@cos(angle)),
    },
};

/// fractional Brownian motion (fBm), also called a fractal Brownian motion
/// https://en.wikipedia.org/wiki/Fractional_Brownian_motion
/// fbm noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/fbm/
fn fbm(comptime octaves: i32, vec: laz.Vec2) Real {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 1.0; // change a lot the visual aspect
    const G = laz.toS(std.math.exp2(-H));
    var f = laz.toS(1.0);
    var a = laz.toS(0.5);
    var t = laz.toS(0.0);
    inline for (0..octaves) |_| {
        t += a * simplex.noise(mtx.mulvec2(vec).mul1(f));
        f *= laz.toS(1.9);
        a *= G;
    }
    return t;
}

/// Same as above but tuned differently
fn fbm6(vec: laz.Vec2) Real {
    // H (Hurst exponent) determines the self similarity it recommand to use 0.5
    const H = 1.0; // change a lot the visual aspect
    const G = laz.toS(std.math.exp2(-H));
    var f = laz.toS(1.0);
    var a = laz.toS(0.5);
    var t = laz.toS(0.0);
    inline for (0..6) |_| {
        t += a * simplex.noise(mtx.mulvec2(vec).mul1(f));
        f *= laz.toS(2.1);
        a *= G;
    }
    return t * laz.toS(1.1);
}

fn pattern(p: laz.Vec2) struct { Real, laz.Vec2, laz.Vec2 } {
    // low frequency
    const q: laz.Vec2 = .{
        .x = laz.toV(0.5) + laz.toS(0.5) * fbm(4, .{ .x = p.x + laz.toS(1.1), .y = p.y + laz.toS(0.1) }),
        .y = laz.toS(0.5) + laz.toS(0.5) * fbm(4, .{ .x = p.x + laz.toS(5.1), .y = p.y + laz.toS(1.5) }),
    };

    // mid frequency
    const r: laz.Vec2 = .{
        .x = laz.toS(0.5) - laz.toS(0.5) * fbm6(.{ .x = p.x + laz.toS(4.1) * q.x, .y = p.y + laz.toS(4.1) * q.y }),
        .y = laz.toS(0.5) - laz.toS(0.5) * fbm6(.{ .x = p.x + laz.toS(4.1) * q.x, .y = p.y + laz.toS(4.1) * q.y }),
    };

    // high frequency
    const f = laz.toS(0.5) + laz.toS(0.5) * fbm(4, p.add(r.mul1(laz.toS(2.1))));
    return .{ f, r, q };
}

/// Generate an image of given width and height using domain warping and fbm noise
/// The code is a bit long and hard to read mainly because it use simd operations to speed up processing
pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32) !std.ArrayList(u8) {
    var data: std.ArrayList(u8) = .empty;
    try data.appendNTimes(allocator, 0, width * height * 3);

    // variable to simulate time and allow to select a different variation of the pattern
    const time = 125.0;

    const scale = laz.toS(1000.0);
    const sin_time = laz.toS(@sin(time));

    const iota = std.simd.iota(f32, vec_len);

    for (0..height) |i| {
        const y: Real = @as(Real, @splat(@as(f32, @floatFromInt(i)))) / scale + sin_time;

        // We use simd code to do the processing
        // So we process vec_len pixels in the width direction at a time
        // pixel in the vector are always in the same line
        for (0..width / vec_len) |j| {
            const x = (iota + @as(Real, @splat(@as(f32, @floatFromInt(j * vec_len))))) / scale + sin_time;

            // Compute base pattern
            // f represents the intensity of the pattern high frequency details
            // r are the mid frequency details
            // q are the low frequency details
            const f, const r, const q = pattern(.{ .x = x, .y = y });

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
                laz.toS(0.5) * smoothstep(laz.toS(1.1), laz.toS(1.3), @abs(r.x) + @abs(r.y)),
            );

            // After the main color is compute we add some lighting to add extra small details.
            // Compute derivative of the pattern : df/dx and df/dy using finite difference
            // It should be possible to compute the derivative analytically
            // because 2/3 of the computation is for this derivative
            const e = laz.toS(1.0) / scale;
            const fex, _, _ = pattern(.{ .x = x + e, .y = y });
            const fey, _, _ = pattern(.{ .x = x, .y = y + e });

            // compute surface normal
            // normal.x is the derivative of pattern along x
            // normal.y is the derivative of pattern along y
            // normal.z is the step
            const normal = laz.Vec3.normalize(.{ .x = fex - f, .y = fey - f, .z = e });

            // we define a light direction
            const light = laz.Vec3.normalize(.{ .x = laz.toS(0.5), .y = laz.toS(-0.3), .z = laz.toS(-0.1) });
            // we compute the diffuse term
            const diff = std.math.clamp(laz.toS(0.5) + laz.toS(0.9) * laz.Vec3.dot(normal, light), laz.toS(0.0), laz.toS(1.0));
            const lin: laz.Vec3 = .{
                .x = (normal.z * laz.toS(0.2) + laz.toS(0.7)) + laz.toS(0.1) * diff,
                .y = (normal.z * laz.toS(0.2) + laz.toS(0.7)) + laz.toS(0.1) * diff,
                .z = (normal.z * laz.toS(0.2) + laz.toS(0.7)) + laz.toS(0.1) * diff,
            };
            col = col.mul(lin);

            // Increase contrast on high frequency details
            col = col.mul1(f * laz.toS(2.0));

            // Inverse value and apply a gamma curve to boost contrast
            // std.math.pow is not vectorized so we do it manually
            const temp = laz.Vec3.ones().sub(col);
            col = temp.mul(temp).mul(temp); // gamma 3

            const r_u8 = @as(@Vector(vec_len, u8), @intFromFloat(std.math.clamp(col.x * laz.toS(255), laz.toS(0), laz.toS(255))));
            const g_u8 = @as(@Vector(vec_len, u8), @intFromFloat(std.math.clamp(col.y * laz.toS(255), laz.toS(0), laz.toS(255))));
            const b_u8 = @as(@Vector(vec_len, u8), @intFromFloat(std.math.clamp(col.z * laz.toS(255), laz.toS(0), laz.toS(255))));
            // stb expect data to be in interlaced RGBRGBRGB.. format
            data.items[i * width * 3 + j * 3 * vec_len ..][0 .. vec_len * 3].* = std.simd.interlace(.{ r_u8, g_u8, b_u8 });
        }
    }

    return data;
}

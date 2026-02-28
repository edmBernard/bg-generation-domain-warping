//! 2D and 3D simplex noise.
//!
//! The 2D implementation is adapted from Inigo Quilez:
//!   https://iquilezles.org/articles/fbm/
//! The 3D implementation follows the standard simplex noise algorithm described in:
//!   https://en.wikipedia.org/wiki/Simplex_noise
//!   https://thebookofshaders.com/11/
//!
//! All operations use SIMD vectors for batch evaluation.

const std = @import("std");

const zpp = @import("zpp");
const working_type = @import("working_type.zig");
const f32v = working_type.f32v;
const laf = zpp.zla.with(f32v);

/// A periodic triangle function with period 4 and range [-1, 1].
/// Using this instead of sin improves performance by a factor of 5 on the whole generation
/// and results are similar enough.
inline fn triangle_func(in: f32v) f32v {
    const z = in * laf.splat(0.25);
    const f = laf.splat(2.0) * @abs(z - @floor(z) - laf.splat(0.5));
    return laf.splat(2.0) * f - laf.splat(1.0);
}

/// A smoothstep-eased periodic function with period 4 and range [-1, 1].
/// Same shape as `triangle_func` but with a cubic ease (smoothstep) applied,
/// producing a closer approximation to sin.
inline fn periodic_func(in: f32v) f32v {
    const z = in * laf.splat(0.25);
    const f = laf.splat(2.0) * @abs(z - @floor(z) - laf.splat(0.5));
    const g = f * f * (laf.splat(3.0) - laf.splat(2.0) * f);
    return laf.splat(2.0) * g - laf.splat(1.0);
}

/// Hash a 2D lattice point to a pseudo-random gradient vector in [-1, 1]^2.
/// Each component is computed as a dot product with magic constants, passed through
/// `triangle_func`, multiplied by a large number, then `fract`ed and remapped to [-1, 1].
inline fn hash2(p: laf.Vec2) laf.Vec2 {
    const temp = .{
        .x = p.dot(.{ .x = @splat(127.1), .y = @splat(311.7) }),
        .y = p.dot(.{ .x = @splat(269.5), .y = @splat(183.3) }),
    };
    return .{
        .x = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(triangle_func(temp.x) * laf.splat(43758.5453123)),
        .y = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(triangle_func(temp.y) * laf.splat(43758.5453123)),
    };
}

/// Hash a 3D lattice point to a pseudo-random gradient vector in [-1, 1]^3.
/// Three independent dot products with different magic constants, each passed through
/// `triangle_func` + `fract`, then remapped to [-1, 1].
inline fn hash3(p: laf.Vec3) laf.Vec3 {
    const temp: laf.Vec3 = .{
        .x = p.dot(.{ .x = @splat(127.1), .y = @splat(311.7), .z = @splat(74.7) }),
        .y = p.dot(.{ .x = @splat(269.5), .y = @splat(183.3), .z = @splat(246.1) }),
        .z = p.dot(.{ .x = @splat(113.5), .y = @splat(271.9), .z = @splat(124.6) }),
    };
    return .{
        .x = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(triangle_func(temp.x) * laf.splat(43758.5453123)),
        .y = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(triangle_func(temp.y) * laf.splat(43758.5453123)),
        .z = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(triangle_func(temp.z) * laf.splat(43758.5453123)),
    };
}

/// 2D simplex noise. Returns a value in approximately [-1, 1].
///
/// Algorithm overview:
///   1. Skew input space with K1 = (sqrt(3)-1)/2 to map the triangular simplex grid onto a square grid.
///   2. Determine which triangle (simplex) the point lies in and compute 3 corner offsets.
///   3. Unskew corner offsets back to original space with K2 = (3-sqrt(3))/6.
///   4. For each corner, compute radial falloff: max(0.5 - |d|^2, 0)^4 * dot(gradient, d).
///   5. Sum contributions and scale by 70 to normalize output range.
///
/// Adapted from Inigo Quilez: https://iquilezles.org/articles/fbm/
pub fn noise(p: laf.Vec2) laf.InnerType {
    // Skew and unskew constants for 2D simplex
    const K1 = laf.splat(0.366025404); // (sqrt(3)-1)/2
    const K2 = laf.splat(0.211324865); // (3-sqrt(3))/6

    // Step 1: Skew input to find simplex cell origin
    const s = (p.x + p.y) * K1;
    const i = @floor(p.x + s);
    const j = @floor(p.y + s);

    // Step 2-3: Unskew to get offset from first corner (a), determine triangle, compute other offsets (b, c)
    // b'----c
    // |    /|
    // |  /  |
    // |/    |
    // a --- b
    const t = (i + j) * K2;
    const a: laf.Vec2 = .{ .x = p.x - i + t, .y = p.y - j + t };
    const m: laf.InnerType = @select(f32, a.x < a.y, laf.splat(0), laf.splat(1));
    const o: laf.Vec2 = .{ .x = m, .y = laf.splat(1.0) - m };
    const b: laf.Vec2 = .{ .x = a.x - o.x + K2, .y = a.y - o.y + K2 };
    const c: laf.Vec2 = .{ .x = a.x - laf.splat(1.0) + laf.splat(2.0) * K2, .y = a.y - laf.splat(1.0) + laf.splat(2.0) * K2 };

    // Step 4: Radial falloff max(0.5 - |d|^2, 0)^4 for each corner
    const na = @max(laf.splat(0.5) - a.dot(a), laf.splat(0));
    const nb = @max(laf.splat(0.5) - b.dot(b), laf.splat(0));
    const nc = @max(laf.splat(0.5) - c.dot(c), laf.splat(0));

    // Falloff^4 * dot(gradient, offset) per corner
    const n: laf.Vec3 = .{
        .x = na * na * na * na * a.dot(hash2(.{ .x = i + laf.splat(0.0), .y = j + laf.splat(0.0) })),
        .y = nb * nb * nb * nb * b.dot(hash2(.{ .x = i + o.x, .y = j + o.y })),
        .z = nc * nc * nc * nc * c.dot(hash2(.{ .x = i + laf.splat(1.0), .y = j + laf.splat(1.0) })),
    };

    // Step 5: Scale by 70 to normalize
    return (n.x + n.y + n.z) * laf.splat(70);
}

/// 3D simplex noise. Returns a value in approximately [-1, 1].
///
/// Algorithm overview:
///   1. Skew input space with F3 = 1/3 to map the tetrahedral simplex grid onto a cubic grid.
///   2. Determine which of the 6 tetrahedra the point lies in via branchless `@select` comparisons.
///   3. Unskew with G3 = 1/6 to compute 4 corner offset vectors.
///   4. For each corner, compute radial falloff: max(0.6 - |d|^2, 0)^4 * dot(gradient, d).
///      The 0.6 radius (vs 0.5 in 2D) is standard for 3D simplex noise.
///   5. Sum contributions and scale by 32 to normalize output range.
pub fn noise3d(p: laf.Vec3) laf.InnerType {
    // Skew and unskew constants for 3D simplex
    const F3 = laf.splat(1.0 / 3.0);
    const G3 = laf.splat(1.0 / 6.0);

    // Step 1: Skew input to find simplex cell origin
    const s = (p.x + p.y + p.z) * F3;
    const i = @floor(p.x + s);
    const j = @floor(p.y + s);
    const k = @floor(p.z + s);

    // Step 2-3: Unskew to get offset from first corner
    const t = (i + j + k) * G3;
    const x0 = p.x - (i - t);
    const y0 = p.y - (j - t);
    const z0 = p.z - (k - t);

    // Determine which tetrahedron we're in (1 of 6) using branchless @select
    const ge_xy = x0 >= y0;
    const ge_yz = y0 >= z0;
    const ge_xz = x0 >= z0;

    // Second corner offsets
    const c1_i = @select(f32, ge_xy & ge_xz, laf.splat(1), laf.splat(0));
    const c1_j = @select(f32, !ge_xy & ge_yz, laf.splat(1), laf.splat(0));
    const c1_k = @select(f32, !ge_yz & !ge_xz, laf.splat(1), laf.splat(0));

    // Third corner offsets
    const c2_i = @select(f32, ge_xy | ge_xz, laf.splat(1), laf.splat(0));
    const c2_j = @select(f32, !ge_xy | ge_yz, laf.splat(1), laf.splat(0));
    const c2_k = @select(f32, !ge_yz | !ge_xz, laf.splat(1), laf.splat(0));

    // Offset vectors for corners 1, 2, and 3
    const x1 = x0 - c1_i + G3;
    const y1 = y0 - c1_j + G3;
    const z1 = z0 - c1_k + G3;
    const x2 = x0 - c2_i + laf.splat(2.0) * G3;
    const y2 = y0 - c2_j + laf.splat(2.0) * G3;
    const z2 = z0 - c2_k + laf.splat(2.0) * G3;
    const x3 = x0 - laf.splat(1.0) + laf.splat(3.0) * G3;
    const y3 = y0 - laf.splat(1.0) + laf.splat(3.0) * G3;
    const z3 = z0 - laf.splat(1.0) + laf.splat(3.0) * G3;

    // Step 4: Radial falloff max(0.6 - |d|^2, 0)^4 for each of 4 corners
    const zero = laf.splat(0);
    const radius = laf.splat(0.6);

    var t0 = radius - (x0 * x0 + y0 * y0 + z0 * z0);
    var t1 = radius - (x1 * x1 + y1 * y1 + z1 * z1);
    var t2 = radius - (x2 * x2 + y2 * y2 + z2 * z2);
    var t3 = radius - (x3 * x3 + y3 * y3 + z3 * z3);

    t0 = @max(t0, zero);
    t1 = @max(t1, zero);
    t2 = @max(t2, zero);
    t3 = @max(t3, zero);

    t0 = t0 * t0;
    t1 = t1 * t1;
    t2 = t2 * t2;
    t3 = t3 * t3;

    // Gradient contribution: falloff^4 * dot(gradient, offset)
    const g0 = hash3(.{ .x = i, .y = j, .z = k });
    const g1 = hash3(.{ .x = i + c1_i, .y = j + c1_j, .z = k + c1_k });
    const g2 = hash3(.{ .x = i + c2_i, .y = j + c2_j, .z = k + c2_k });
    const g3 = hash3(.{ .x = i + laf.splat(1), .y = j + laf.splat(1), .z = k + laf.splat(1) });

    const n0 = t0 * t0 * (g0.x * x0 + g0.y * y0 + g0.z * z0);
    const n1 = t1 * t1 * (g1.x * x1 + g1.y * y1 + g1.z * z1);
    const n2 = t2 * t2 * (g2.x * x2 + g2.y * y2 + g2.z * z2);
    const n3 = t3 * t3 * (g3.x * x3 + g3.y * y3 + g3.z * z3);

    // Step 5: Scale by 32 to normalize
    return laf.splat(32.0) * (n0 + n1 + n2 + n3);
}

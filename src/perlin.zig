const std = @import("std");
const zpp = @import("zpp");

const working_type = @import("working_type.zig");
const f32v = working_type.f32v;
const laf = zpp.zla.with(f32v);

/// A periodic triangle function
/// using this instead of sin improve performance by a factor 5 on the whole generation
/// and result are similar enough
inline fn triangle_func(in: f32v) f32v {
    const z = in * laf.splat(0.25);
    const f = laf.splat(2.0) * @abs(z - @floor(z) - laf.splat(0.5));
    return laf.splat(2.0) * f - laf.splat(1.0);
}

inline fn hash2(p: laf.Vec2) laf.Vec2 {
    const temp = .{
        .x = laf.Vec2.dot(p, .{ .x = laf.splat(127.1), .y = laf.splat(311.7) }),
        .y = laf.Vec2.dot(p, .{ .x = laf.splat(269.5), .y = laf.splat(193.3) }),
    };
    return .{
        .x = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(triangle_func(temp.x) * laf.splat(43758.5453123)),
        .y = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(triangle_func(temp.y) * laf.splat(43758.5453123)),
    };
}

fn fade(t: f32v) f32v {
    return t * t * t * (t * (t * laf.splat(6.0) - laf.splat(15.0)) + laf.splat(10.0));
}

/// Gradient noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/noise/
// https://cs.nyu.edu/~perlin/noise/
// Ideally I should have keep the 3D aspect of it but for now 2D is enough and simpler to implement in simd
pub fn noise_gradient(p: laf.Vec2) f32v {
    // Find unit cube that contains point.
    const ix = @floor(p.x);
    const iy = @floor(p.y);

    // Find relative x,y of point in square.
    const fx = p.x - @floor(p.x);
    const fy = p.y - @floor(p.y);

    // Compute fade curves for each of x,y
    const u = fade(fx);
    const v = fade(fy);

    // gradients
    const ga = hash2(.{ .x = ix + laf.splat(0.0), .y = iy + laf.splat(0.0) });
    const gb = hash2(.{ .x = ix + laf.splat(1.0), .y = iy + laf.splat(0.0) });
    const gc = hash2(.{ .x = ix + laf.splat(0.0), .y = iy + laf.splat(1.0) });
    const gd = hash2(.{ .x = ix + laf.splat(1.0), .y = iy + laf.splat(1.0) });

    // projections
    const va = ga.dot(.{ .x = fx - laf.splat(0.0), .y = fy - laf.splat(0.0) });
    const vb = gb.dot(.{ .x = fx - laf.splat(1.0), .y = fy - laf.splat(0.0) });
    const vc = gc.dot(.{ .x = fx - laf.splat(0.0), .y = fy - laf.splat(1.0) });
    const vd = gd.dot(.{ .x = fx - laf.splat(1.0), .y = fy - laf.splat(1.0) });

    return va + u * (vb - va) + v * (vc - va) + u * v * (va - vb - vc + vd);
}

const std = @import("std");

const laz = @import("linearalgebra.zig");

/// A periodic triangle function
/// using this instead of sin improve performance by a factor 5 on the whole generation
/// and result are similar enough
inline fn triangle_func(in: laz.InnerType) laz.InnerType {
    const z = in * laz.toV(0.25);
    const f = laz.toV(2.0) * @abs(z - @floor(z) - laz.toV(0.5));
    return laz.toV(2.0) * f - laz.toV(1.0);
}

inline fn fake_hash(p: laz.Vec2) laz.Vec2 {
    const temp = .{
        .x = laz.Vec2.dot(p, .{ .x = laz.toV(127.1), .y = laz.toV(311.7) }),
        .y = laz.Vec2.dot(p, .{ .x = laz.toV(269.5), .y = laz.toV(193.3) }),
    };
    return .{
        .x = laz.toV(1.0) * laz.fract(triangle_func(temp.x) * laz.toV(43758.5453123)),
        .y = laz.toV(1.0) * laz.fract(triangle_func(temp.y) * laz.toV(43758.5453123)),
    };
}

inline fn hash2(p: laz.Vec2) laz.Vec2 {
    const temp = .{
        .x = laz.Vec2.dot(p, .{ .x = laz.toV(127.1), .y = laz.toV(311.7) }),
        .y = laz.Vec2.dot(p, .{ .x = laz.toV(269.5), .y = laz.toV(193.3) }),
    };
    return .{
        .x = laz.toV(-1.0) + laz.toV(2.0) * laz.fract(triangle_func(temp.x) * laz.toV(43758.5453123)),
        .y = laz.toV(-1.0) + laz.toV(2.0) * laz.fract(triangle_func(temp.y) * laz.toV(43758.5453123)),
    };
}

fn fade(t: laz.InnerType) laz.InnerType {
    return t * t * t * (t * (t * laz.toV(6.0) - laz.toV(15.0)) + laz.toV(10.0));
}

fn grad(hash: laz.Vec2, x: laz.InnerType, y: laz.InnerType) laz.InnerType {
    // Convert low 4 bits of hash code into 12 gradient directions.
    const i32_v: type = @Vector(laz.vec_len, i32);
    const h = @as(i32_v, @intFromFloat(hash.x)) & @as(i32_v, @splat(0b1111));
    const i_0 = @as(i32_v, @splat(0));
    const i_1 = @as(i32_v, @splat(1));
    const i_2 = @as(i32_v, @splat(2));
    const i_4 = @as(i32_v, @splat(4));
    const i_8 = @as(i32_v, @splat(8));
    const i_12 = @as(i32_v, @splat(12));
    const i_14 = @as(i32_v, @splat(14));
    const u = @select(f32, h < i_8, x, y);
    // I don't know how to express or properly in simd so I do two select.
    const temp1 = @select(f32, (h == i_12), x, @select(f32, (h == i_14), x, laz.toV(0.0)));
    const v = @select(f32, h < i_4, y, temp1);
    return @select(f32, (h & i_1) == i_0, u, -u) + @select(f32, (h & i_2) == i_0, v, -v);
}

// Perlin noise implemented from the reference implementation from 2002
// https://cs.nyu.edu/~perlin/noise/
// Ideally I should have keep the 3D aspect of it but for now 2D is enough
// and simpler to implement in simd
pub fn noise_perlin(p: laz.Vec2) laz.InnerType {
    // Find unit cube that contains point.
    const X = @floor(p.x);
    const Y = @floor(p.y);

    // Find relative x,y of point in square.
    const x = p.x - @floor(p.x);
    const y = p.y - @floor(p.y);

    // Compute fade curves for each of x,y
    const u = fade(x);
    const v = fade(y);

    // Hash coordinates of the 4 square corners
    // I'm not smart enough to convert the accessor logic in simd so I reuse the hash from my previous implementation
    const A00 = fake_hash(.{ .x = X, .y = Y });
    const A10 = fake_hash(.{ .x = X + laz.toV(1), .y = Y });
    const A01 = fake_hash(.{ .x = X, .y = Y + laz.toV(1) });
    const A11 = fake_hash(.{ .x = X + laz.toV(1), .y = Y + laz.toV(1) });

    // zig lerp function is (a,b,t) not (t,a,b) like in the reference implementation
    return std.math.lerp(
        std.math.lerp(
            grad(A00, x, y),
            grad(A10, x - laz.toV(1.0), y),
            u,
        ),
        std.math.lerp(
            grad(A01, x, y - laz.toV(1.0)),
            grad(A11, x - laz.toV(1.0), y - laz.toV(1.0)),
            u,
        ),
        v,
    );
}

/// Gradient noise implementation adapted from Inigo Quilez : https://iquilezles.org/articles/noise/
pub fn noise_gradient(p: laz.Vec2) laz.InnerType {
    // std.log.err("I suppose there is a bug somewhere. It generates directional artifacts.", .{});
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
    const ga = hash2(.{ .x = ix + laz.toV(0.0), .y = iy + laz.toV(0.0) });
    const gb = hash2(.{ .x = ix + laz.toV(1.0), .y = iy + laz.toV(0.0) });
    const gc = hash2(.{ .x = ix + laz.toV(0.0), .y = iy + laz.toV(1.0) });
    const gd = hash2(.{ .x = ix + laz.toV(1.0), .y = iy + laz.toV(1.0) });

    // projections
    const va = ga.dot(.{ .x = fx - laz.toV(0.0), .y = fy - laz.toV(0.0) });
    const vb = gb.dot(.{ .x = fx - laz.toV(1.0), .y = fy - laz.toV(0.0) });
    const vc = gc.dot(.{ .x = fx - laz.toV(0.0), .y = fy - laz.toV(1.0) });
    const vd = gd.dot(.{ .x = fx - laz.toV(1.0), .y = fy - laz.toV(1.0) });

    return va + u * (vb - va) + v * (vc - va) + u * v * (va - vb - vc + vd);
}

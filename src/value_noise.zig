//! 2D value noise matching the GLSL domain_warping.glsl implementation.
//!
//! Value noise hashes lattice points to scalar values in [0, 1] and
//! bilinearly interpolates between them. Uses linear interpolation
//! (no smoothstep) to match the GLSL shader.

const zpp = @import("zpp");
const working_type = @import("working_type.zig");
const f32v = working_type.f32v;
const laf = zpp.zla.with(f32v);
const periodic = @import("periodic.zig");
const hash = @import("hash.zig");

inline fn hash_1d(p: laf.Vec2) f32v {
    return hash.hash2(p).x;
}

/// 2D value noise with linear interpolation. Returns values in [0, 1].
pub fn noise(x: laf.Vec2) f32v {
    const i: laf.Vec2 = .{ .x = @floor(x.x), .y = @floor(x.y) };
    const f: laf.Vec2 = .{ .x = x.x - @floor(x.x), .y = x.y - @floor(x.y) };

    const a = hash_1d(i);
    const b = hash_1d(.{ .x = i.x + laf.splat(1.0), .y = i.y });
    const c = hash_1d(.{ .x = i.x, .y = i.y + laf.splat(1.0) });
    const d = hash_1d(.{ .x = i.x + laf.splat(1.0), .y = i.y + laf.splat(1.0) });

    // Bilinear interpolation
    const ux = f.x;
    const uy = f.y;
    return a + (b - a) * ux + (c - a) * uy * (laf.splat(1.0) - ux) + (d - b) * ux * uy;
}

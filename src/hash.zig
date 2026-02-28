//! Hash functions that map lattice points to pseudo-random gradient vectors.
//!
//! Used by noise algorithms (simplex, perlin) to generate repeatable
//! pseudo-random gradients at integer lattice points.

const std = @import("std");
const zpp = @import("zpp");
const working_type = @import("working_type.zig");
const f32v = working_type.f32v;
const laf = zpp.zla.with(f32v);
const periodic = @import("periodic.zig");

/// Hash a 2D lattice point to a pseudo-random gradient vector in [-1, 1]^2.
/// Each component is computed as a dot product with magic constants, passed through
/// `triangle_func`, multiplied by a large number, then `fract`ed and remapped to [-1, 1].
pub inline fn hash2(p: laf.Vec2) laf.Vec2 {
    const temp = .{
        .x = p.dot(.{ .x = @splat(127.1), .y = @splat(311.7) }),
        .y = p.dot(.{ .x = @splat(269.5), .y = @splat(183.3) }),
    };
    return .{
        .x = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(periodic.triangle_func(temp.x) * laf.splat(43758.5453123)),
        .y = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(periodic.triangle_func(temp.y) * laf.splat(43758.5453123)),
    };
}

/// Hash a 3D lattice point to a pseudo-random gradient vector in [-1, 1]^3.
/// Three independent dot products with different magic constants, each passed through
/// `triangle_func` + `fract`, then remapped to [-1, 1].
pub inline fn hash3(p: laf.Vec3) laf.Vec3 {
    const temp: laf.Vec3 = .{
        .x = p.dot(.{ .x = @splat(127.1), .y = @splat(311.7), .z = @splat(74.7) }),
        .y = p.dot(.{ .x = @splat(269.5), .y = @splat(183.3), .z = @splat(246.1) }),
        .z = p.dot(.{ .x = @splat(113.5), .y = @splat(271.9), .z = @splat(124.6) }),
    };
    return .{
        .x = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(periodic.triangle_func(temp.x) * laf.splat(43758.5453123)),
        .y = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(periodic.triangle_func(temp.y) * laf.splat(43758.5453123)),
        .z = laf.splat(-1.0) + laf.splat(2.0) * zpp.math.fract(periodic.triangle_func(temp.z) * laf.splat(43758.5453123)),
    };
}

test "hash2 output is in [-1, 1]" {
    const inputs = [_]f32{ 0.0, 1.0, -1.0, 42.0, 100.0, -37.5 };
    for (inputs) |x| {
        for (inputs) |y| {
            const result = hash2(.{ .x = laf.splat(x), .y = laf.splat(y) });
            try std.testing.expect(result.x[0] >= -1.0 - 1e-6);
            try std.testing.expect(result.x[0] <= 1.0 + 1e-6);
            try std.testing.expect(result.y[0] >= -1.0 - 1e-6);
            try std.testing.expect(result.y[0] <= 1.0 + 1e-6);
        }
    }
}

test "hash2 is deterministic" {
    const a = hash2(.{ .x = laf.splat(3.0), .y = laf.splat(7.0) });
    const b = hash2(.{ .x = laf.splat(3.0), .y = laf.splat(7.0) });
    try std.testing.expectApproxEqAbs(a.x[0], b.x[0], 1e-6);
    try std.testing.expectApproxEqAbs(a.y[0], b.y[0], 1e-6);
}

test "hash2 different inputs give different outputs" {
    const a = hash2(.{ .x = laf.splat(0.0), .y = laf.splat(0.0) });
    const b = hash2(.{ .x = laf.splat(1.0), .y = laf.splat(0.0) });
    const c = hash2(.{ .x = laf.splat(0.0), .y = laf.splat(1.0) });
    // At least one component should differ
    const ab_diff = @abs(a.x[0] - b.x[0]) + @abs(a.y[0] - b.y[0]);
    const ac_diff = @abs(a.x[0] - c.x[0]) + @abs(a.y[0] - c.y[0]);
    try std.testing.expect(ab_diff > 1e-6);
    try std.testing.expect(ac_diff > 1e-6);
}

test "hash3 output is in [-1, 1]" {
    const inputs = [_]f32{ 0.0, 1.0, -1.0, 42.0, 100.0 };
    for (inputs) |x| {
        for (inputs) |y| {
            for (inputs) |z| {
                const result = hash3(.{ .x = laf.splat(x), .y = laf.splat(y), .z = laf.splat(z) });
                try std.testing.expect(result.x[0] >= -1.0 - 1e-6);
                try std.testing.expect(result.x[0] <= 1.0 + 1e-6);
                try std.testing.expect(result.y[0] >= -1.0 - 1e-6);
                try std.testing.expect(result.y[0] <= 1.0 + 1e-6);
                try std.testing.expect(result.z[0] >= -1.0 - 1e-6);
                try std.testing.expect(result.z[0] <= 1.0 + 1e-6);
            }
        }
    }
}

test "hash3 is deterministic" {
    const a = hash3(.{ .x = laf.splat(3.0), .y = laf.splat(7.0), .z = laf.splat(11.0) });
    const b = hash3(.{ .x = laf.splat(3.0), .y = laf.splat(7.0), .z = laf.splat(11.0) });
    try std.testing.expectApproxEqAbs(a.x[0], b.x[0], 1e-6);
    try std.testing.expectApproxEqAbs(a.y[0], b.y[0], 1e-6);
    try std.testing.expectApproxEqAbs(a.z[0], b.z[0], 1e-6);
}

test "hash3 different inputs give different outputs" {
    const a = hash3(.{ .x = laf.splat(0.0), .y = laf.splat(0.0), .z = laf.splat(0.0) });
    const b = hash3(.{ .x = laf.splat(1.0), .y = laf.splat(0.0), .z = laf.splat(0.0) });
    const c = hash3(.{ .x = laf.splat(0.0), .y = laf.splat(1.0), .z = laf.splat(0.0) });
    const ab_diff = @abs(a.x[0] - b.x[0]) + @abs(a.y[0] - b.y[0]) + @abs(a.z[0] - b.z[0]);
    const ac_diff = @abs(a.x[0] - c.x[0]) + @abs(a.y[0] - c.y[0]) + @abs(a.z[0] - c.z[0]);
    try std.testing.expect(ab_diff > 1e-6);
    try std.testing.expect(ac_diff > 1e-6);
}

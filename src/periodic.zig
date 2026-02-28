//! Periodic functions used as building blocks for noise hash functions.
//!
//! These are fast approximations to sine-like periodic functions,
//! designed for use in SIMD noise generation pipelines.

const std = @import("std");
const zpp = @import("zpp");
const working_type = @import("working_type.zig");
const f32v = working_type.f32v;
const laf = zpp.zla.with(f32v);

/// A periodic triangle function with period 4 and range [-1, 1].
/// Using this instead of sin improves performance by a factor of 5 on the whole generation
/// and results are similar enough.
pub inline fn triangle_func(in: f32v) f32v {
    const z = in * laf.splat(0.25);
    const f = laf.splat(2.0) * @abs(z - @floor(z) - laf.splat(0.5));
    return laf.splat(2.0) * f - laf.splat(1.0);
}

/// A smoothstep-eased periodic function with period 4 and range [-1, 1].
/// Same shape as `triangle_func` but with a cubic ease (smoothstep) applied,
/// producing a closer approximation to sin.
pub inline fn periodic_func(in: f32v) f32v {
    const z = in * laf.splat(0.25);
    const f = laf.splat(2.0) * @abs(z - @floor(z) - laf.splat(0.5));
    const g = f * f * (laf.splat(3.0) - laf.splat(2.0) * f);
    return laf.splat(2.0) * g - laf.splat(1.0);
}

test "triangle_func is periodic with period 4" {
    const result_0 = triangle_func(laf.splat(0.0));
    const result_4 = triangle_func(laf.splat(4.0));
    const result_neg4 = triangle_func(laf.splat(-4.0));
    try std.testing.expectApproxEqAbs(result_0[0], result_4[0], 1e-6);
    try std.testing.expectApproxEqAbs(result_0[0], result_neg4[0], 1e-6);
}

test "triangle_func known values" {
    // triangle_func(0) = 1, triangle_func(1) = 0, triangle_func(2) = -1, triangle_func(3) = 0
    try std.testing.expectApproxEqAbs(triangle_func(laf.splat(0.0))[0], 1.0, 1e-6);
    try std.testing.expectApproxEqAbs(triangle_func(laf.splat(1.0))[0], 0.0, 1e-6);
    try std.testing.expectApproxEqAbs(triangle_func(laf.splat(2.0))[0], -1.0, 1e-6);
    try std.testing.expectApproxEqAbs(triangle_func(laf.splat(3.0))[0], 0.0, 1e-6);
}

test "triangle_func range is [-1, 1]" {
    var i: f32 = -10.0;
    while (i <= 10.0) : (i += 0.1) {
        const result = triangle_func(laf.splat(i));
        try std.testing.expect(result[0] >= -1.0 - 1e-6);
        try std.testing.expect(result[0] <= 1.0 + 1e-6);
    }
}

test "periodic_func is periodic with period 4" {
    const result_0 = periodic_func(laf.splat(0.0));
    const result_4 = periodic_func(laf.splat(4.0));
    const result_neg4 = periodic_func(laf.splat(-4.0));
    try std.testing.expectApproxEqAbs(result_0[0], result_4[0], 1e-6);
    try std.testing.expectApproxEqAbs(result_0[0], result_neg4[0], 1e-6);
}

test "periodic_func known values" {
    // Same extremes as triangle_func: 1 at 0, -1 at 2, 0 at 1 and 3
    try std.testing.expectApproxEqAbs(periodic_func(laf.splat(0.0))[0], 1.0, 1e-6);
    try std.testing.expectApproxEqAbs(periodic_func(laf.splat(1.0))[0], 0.0, 1e-6);
    try std.testing.expectApproxEqAbs(periodic_func(laf.splat(2.0))[0], -1.0, 1e-6);
    try std.testing.expectApproxEqAbs(periodic_func(laf.splat(3.0))[0], 0.0, 1e-6);
}

test "periodic_func range is [-1, 1]" {
    var i: f32 = -10.0;
    while (i <= 10.0) : (i += 0.1) {
        const result = periodic_func(laf.splat(i));
        try std.testing.expect(result[0] >= -1.0 - 1e-6);
        try std.testing.expect(result[0] <= 1.0 + 1e-6);
    }
}

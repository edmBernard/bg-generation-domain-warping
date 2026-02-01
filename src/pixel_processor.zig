const std = @import("std");
const laz = @import("linearalgebra.zig");

pub fn process(data: *[]u8, width: u32, height: u32, context: anytype, functor: anytype) void {
    const iota = std.simd.iota(f32, laz.vec_len);

    for (0..height) |i| {
        const y: laz.InnerType = @as(laz.InnerType, @splat(@as(f32, @floatFromInt(i))));

        // We use simd code to do the processing
        // So we process laz.vec_len pixels in the width direction at a time
        // pixel in the vector are always in the same line
        for (0..width / laz.vec_len) |j| {
            const x = (iota + @as(laz.InnerType, @splat(@as(f32, @floatFromInt(j * laz.vec_len)))));

            const r, const g, const b = functor(context, x, y);

            const r_u8 = @as(@Vector(laz.vec_len, u8), @intFromFloat(std.math.clamp(r * laz.toV(255), laz.toV(0), laz.toV(255))));
            const g_u8 = @as(@Vector(laz.vec_len, u8), @intFromFloat(std.math.clamp(g * laz.toV(255), laz.toV(0), laz.toV(255))));
            const b_u8 = @as(@Vector(laz.vec_len, u8), @intFromFloat(std.math.clamp(b * laz.toV(255), laz.toV(0), laz.toV(255))));
            // stb expect data to be in interlaced RGBRGBRGB.. format
            data.*[i * width * 3 + j * 3 * laz.vec_len ..][0 .. laz.vec_len * 3].* = std.simd.interlace(.{ r_u8, g_u8, b_u8 });
        }
    }
}

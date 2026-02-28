const zpp = @import("zpp");
const working_type = @import("working_type.zig");
const f32v = working_type.f32v;
const laf = zpp.zla.with(f32v);

/// The hex color is in format 0xRRGGBBAA
pub inline fn hexToVec3(comptime hex: u32) laf.Vec3 {
    return .{
        .x = @splat(@as(f32, @floatFromInt((hex & 0xFF000000) >> 24)) / 255.0),
        .y = @splat(@as(f32, @floatFromInt((hex & 0x00FF0000) >> 16)) / 255.0),
        .z = @splat(@as(f32, @floatFromInt((hex & 0x0000FF00) >> 8)) / 255.0),
    };
}

const std = @import("std");

/// Makes all vector types generic against f32 and simd vector of f32
/// The idea to specialize modul is taken from zlm https://github.com/ziglibs/zlm
/// I don't like the implication that we need to declare test modeules separately
/// Import in other modules make it painful
/// And for the moment it's not really easy to switch calling code between different inner type
/// Because simd code leak in the calling code
pub fn as(comptime InnerType: type) type {
    switch (@typeInfo(InnerType)) {
        .float, .vector => {},
        else => @compileError("Invalid InnerType for linearalgebra"),
    }

    return struct {
        /// Convert a single value to a scalar inner type by splatting it
        /// InnerType is usually a simd vector type
        pub inline fn toS(comptime scalar: f32) InnerType {
            return switch (@typeInfo(InnerType)) {
                .float => return @as(InnerType, scalar),
                .vector => return @splat(scalar),
                else => unreachable,
            };
        }

        // MARK: Helper 1D functions
        pub inline fn fract(x: InnerType) InnerType {
            return x - @floor(x);
        }

        // MARK: Vec2
        pub const Vec2 = struct {
            x: InnerType,
            y: InnerType,

            /// a * b
            pub inline fn mul1(a: Vec2, b: InnerType) Vec2 {
                return .{
                    .x = a.x * b,
                    .y = a.y * b,
                };
            }

            /// a + b
            pub inline fn add1(a: Vec2, b: InnerType) Vec2 {
                return .{
                    .x = a.x + b,
                    .y = a.y + b,
                };
            }

            /// a + b
            pub inline fn add(a: Vec2, b: Vec2) Vec2 {
                return .{
                    .x = a.x + b.x,
                    .y = a.y + b.y,
                };
            }

            /// a - b
            pub inline fn sub1(a: Vec2, b: InnerType) Vec2 {
                return .{
                    .x = a.x - b,
                    .y = a.y - b,
                };
            }

            /// a - b
            pub inline fn sub(a: Vec2, b: Vec2) Vec2 {
                return .{
                    .x = a.x - b.x,
                    .y = a.y - b.y,
                };
            }

            /// - a
            pub inline fn neg(a: Vec2) Vec2 {
                return .{
                    .x = -a.x,
                    .y = -a.y,
                };
            }

            pub inline fn dot(p: Vec2, q: Vec2) InnerType {
                return p.x * q.x + p.y * q.y;
            }
        };

        // MARK: Vec3
        pub const Vec3 = struct {
            x: InnerType,
            y: InnerType,
            z: InnerType,

            pub inline fn ones() Vec3 {
                return .{ .x = toS(1.0), .y = toS(1.0), .z = toS(1.0) };
            }

            pub inline fn mul1(a: Vec3, b: InnerType) Vec3 {
                return .{
                    .x = a.x * b,
                    .y = a.y * b,
                    .z = a.z * b,
                };
            }

            pub inline fn mul(a: Vec3, b: Vec3) Vec3 {
                return .{
                    .x = a.x * b.x,
                    .y = a.y * b.y,
                    .z = a.z * b.z,
                };
            }

            pub inline fn add1(a: Vec3, b: InnerType) Vec3 {
                return .{
                    .x = a.x + b,
                    .y = a.y + b,
                    .z = a.z + b,
                };
            }

            pub inline fn add(a: Vec3, b: Vec3) Vec3 {
                return .{
                    .x = a.x + b.x,
                    .y = a.y + b.y,
                    .z = a.z + b.z,
                };
            }

            pub inline fn sub(a: Vec3, b: Vec3) Vec3 {
                return .{
                    .x = a.x - b.x,
                    .y = a.y - b.y,
                    .z = a.z - b.z,
                };
            }

            pub inline fn neg(a: Vec3) Vec3 {
                return .{
                    .x = -a.x,
                    .y = -a.y,
                    .z = -a.z,
                };
            }

            pub inline fn dot(p: Vec3, q: Vec3) InnerType {
                return p.x * q.x + p.y * q.y + p.z * q.z;
            }

            pub inline fn normalize(v: Vec3) Vec3 {
                const len = @sqrt(Vec3.dot(v, v));
                return .{
                    .x = v.x / len,
                    .y = v.y / len,
                    .z = v.z / len,
                };
            }

            pub inline fn lerp(a: Vec3, b: Vec3, t: InnerType) Vec3 {
                return .{
                    .x = std.math.lerp(a.x, b.x, t),
                    .y = std.math.lerp(a.y, b.y, t),
                    .z = std.math.lerp(a.z, b.z, t),
                };
            }

            pub inline fn pow(a: Vec3, comptime b: InnerType) Vec3 {
                return .{
                    .x = std.math.pow(InnerType, a.x, b),
                    .y = std.math.pow(InnerType, a.y, b),
                    .z = std.math.pow(InnerType, a.z, b),
                };
            }

            // This method is not really usable
            // because lambda function in zig are not easy to declare
            pub inline fn forEach(a: Vec3, fnc: fn (InnerType) InnerType) Vec3 {
                return .{
                    .x = fnc(a.x),
                    .y = fnc(a.y),
                    .z = fnc(a.z),
                };
            }
        };

        // MARK: Matrix2x2
        pub const Mat2x2 = struct {
            data: [4]InnerType,
            pub inline fn mulvec2(m: Mat2x2, b: Vec2) Vec2 {
                return .{
                    .x = m.data[0] * b.x + m.data[1] * b.y,
                    .y = m.data[2] * b.x + m.data[3] * b.y,
                };
            }
        };
    };
}

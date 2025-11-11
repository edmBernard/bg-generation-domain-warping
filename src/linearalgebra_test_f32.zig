const std = @import("std");

const laz = @import("linearalgebra").as(f32);

// MARK: Tests

test "Vec2 Mul1 Static Method" {
    const v = laz.Vec2{ .x = laz.toS(2.0), .y = laz.toS(3.0) };
    const r = laz.Vec2.mul1(v, laz.toS(4.0));
    try std.testing.expect(std.meta.eql(r.x, laz.toS(8.0)));
    try std.testing.expect(std.meta.eql(r.y, laz.toS(12.0)));
}

test "Vec2 Mul1 Method" {
    const v = laz.Vec2{ .x = laz.toS(2.0), .y = laz.toS(3.0) };
    const r = v.mul1(laz.toS(4.0));
    try std.testing.expect(std.meta.eql(r.x, laz.toS(8.0)));
    try std.testing.expect(std.meta.eql(r.y, laz.toS(12.0)));
}

test "Vec2 Add1 Static Method" {
    const v = laz.Vec2{ .x = laz.toS(2.0), .y = laz.toS(3.0) };
    const r = laz.Vec2.add1(v, laz.toS(4.0));
    try std.testing.expect(std.meta.eql(r.x, laz.toS(6.0)));
    try std.testing.expect(std.meta.eql(r.y, laz.toS(7.0)));
}

test "Vec2 Add1 Method" {
    const v = laz.Vec2{ .x = laz.toS(2.0), .y = laz.toS(3.0) };
    const r = v.add1(laz.toS(4.0));
    try std.testing.expect(std.meta.eql(r.x, laz.toS(6.0)));
    try std.testing.expect(std.meta.eql(r.y, laz.toS(7.0)));
}

test "Vec2 Add Static Method" {
    const v = laz.Vec2{ .x = laz.toS(2.0), .y = laz.toS(3.0) };
    const r = laz.Vec2.add(v, laz.Vec2{ .x = laz.toS(4.0), .y = laz.toS(5.0) });
    try std.testing.expect(std.meta.eql(r.x, laz.toS(6.0)));
    try std.testing.expect(std.meta.eql(r.y, laz.toS(8.0)));
}

test "Vec2 Add Method" {
    const v = laz.Vec2{ .x = laz.toS(2.0), .y = laz.toS(3.0) };
    const r = v.add(laz.Vec2{ .x = laz.toS(4.0), .y = laz.toS(5.0) });
    try std.testing.expect(std.meta.eql(r.x, laz.toS(6.0)));
    try std.testing.expect(std.meta.eql(r.y, laz.toS(8.0)));
}

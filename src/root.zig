//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn generate_image(allocator: std.mem.Allocator, width: u32, height: u32) !std.ArrayList(u8) {
    var data = try std.ArrayList(u8).initCapacity(allocator, width * height);
    data.appendNTimesAssumeCapacity(0, width * height);

    for (0..height) |i| {
        for (0..width) |j| {
            data.items[i * width + j] = @intCast((i + j) % 256);
        }
    }

    return data;
}

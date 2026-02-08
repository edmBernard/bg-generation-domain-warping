const std = @import("std");
const stb_wrapper = @import("stb_wrapper");

const variant1 = @import("variant1.zig");
const variant2 = @import("variant2.zig");
const variant3 = @import("variant3.zig");
const laz = @import("linearalgebra.zig");
const simplex = @import("simplex.zig");
const perlin = @import("perlin.zig");
const cli = @import("cli.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // parse command line arguments
    const args = try cli.parse_args(allocator);

    // generate image
    const tic = std.time.microTimestamp();
    var data = switch (args.variant) {
        1 => try variant1.generate_image(allocator, args.width, args.height),
        2 => try variant2.generate_image(allocator, args.width, args.height),
        3 => try variant3.generate_image(allocator, args.width, args.height),
        else => |_| {
            std.log.err("Unsupported variant: {d}", .{args.variant});
            return;
        },
    };
    defer data.deinit(allocator);
    const tac: i64 = std.time.microTimestamp() - tic;
    std.log.info("Image generated in {d:>20.2} s : ", .{@as(f32, @floatFromInt(tac)) / 1_000_000});

    // save to file
    var all_together_slice: [256]u8 = undefined;
    // filename need to be zero terminated for stb_image_write
    const filename = try std.fmt.bufPrintZ(&all_together_slice, "{s}.jpeg", .{args.filename});
    std.debug.print("Writing image to file: {s}\n", .{filename});
    try stb_wrapper.image_write(filename, data.items, args.width, args.height);

    std.log.info("Image written successfully to : {s}.", .{filename});
}

// Import tests from all modules
test {
    // Run tests from all submodules
    _ = cli;
    _ = simplex;
    _ = perlin;
    _ = laz;
    _ = variant1;
    _ = variant2;
    _ = variant3;
}

const std = @import("std");
const bg_generation_variant1 = @import("bg_generation_variant1");
const bg_generation_variant2 = @import("bg_generation_variant2");
const stb_wrapper = @import("stb_wrapper");
pub const cli = @import("cli.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // parse command line arguments
    const args = try cli.parse_args(allocator);

    // generate image
    const tic = std.time.microTimestamp();
    var data = switch (args.variant) {
        1 => try bg_generation_variant1.generate_image(allocator, args.width, args.height),
        2 => try bg_generation_variant2.generate_image(allocator, args.width, args.height),
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

const std = @import("std");
const bg_generation = @import("bg_generation");
const stb_wrapper = @import("stb_wrapper");
pub const cli = @import("cli.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // parse command line arguments
    const args = try cli.parse_args(allocator);

    // generate image
    var data = try bg_generation.generate_image(allocator, args.width, args.height, args.pattern_type);
    defer data.deinit(allocator);

    // save to file
    var all_together_slice: [256]u8 = undefined;
    // filename need to be zero terminated for stb_image_write
    const filename = try std.fmt.bufPrintZ(&all_together_slice, "{s}_{s}.jpeg", .{ args.filename, @tagName(args.pattern_type) });
    std.debug.print("Writing image to file: {s}\n", .{filename});
    try stb_wrapper.image_write(filename, data.items, args.width, args.height);

    std.log.info("Image written successfully to : {s}.", .{filename});
}

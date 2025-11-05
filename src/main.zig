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
    var data = try bg_generation.generate_image(allocator, args.width, args.height);
    defer data.deinit(allocator);

    // save to file
    try stb_wrapper.image_write(args.filename, data.items, args.width, args.height);

    std.log.info("Image written successfully to : {s}.", .{args.filename});
}

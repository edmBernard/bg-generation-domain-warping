const std = @import("std");
const zpp = @import("zpp");
const stb_wrapper = @import("stb_wrapper");

const variant1 = @import("variant1.zig");
const variant2 = @import("variant2.zig");
const variant3 = @import("variant3.zig");

const simplex = @import("simplex.zig");
const perlin = @import("perlin.zig");
const cli = @import("cli.zig");

fn call_variant(allocator: std.mem.Allocator, variant: u32, width: u32, height: u32, time: f32) !std.ArrayList(u8) {
    return switch (variant) {
        1 => try variant1.generate_image(allocator, width, height, time),
        2 => try variant2.generate_image(allocator, width, height, time),
        3 => try variant3.generate_image(allocator, width, height, time),
        else => |_| {
            std.log.err("Unsupported variant: {d}", .{variant});
            return error.UnsupportedVariant;
        },
    };
}

fn generate_single_image(allocator: std.mem.Allocator, args: cli.Params, filename: []const u8) !void {
    const tic = std.time.microTimestamp();
    var data = try call_variant(allocator, args.variant, args.width, args.height, 125.0);
    defer data.deinit(allocator);
    const tac: i64 = std.time.microTimestamp() - tic;
    std.log.info("Image generated in {d:>20.2} s : ", .{@as(f32, @floatFromInt(tac)) / 1_000_000});

    // save to file
    var buffer_for_filename: [256]u8 = undefined;
    // filename need to be zero terminated for stb_image_write
    const full_filename = try std.fmt.bufPrintZ(&buffer_for_filename, "{s}.jpeg", .{filename});
    std.debug.print("Writing image to file: {s}\n", .{full_filename});
    try stb_wrapper.image_write(full_filename, data.items, args.width, args.height);

    std.log.info("Image written successfully to : {s}.", .{full_filename});
}

fn generate_video(allocator: std.mem.Allocator, args: cli.Params, fps: u32, total_frames: u32) !void {
    const stdout = std.fs.File.stdout();
    const frame_size = @as(usize, args.width) * @as(usize, args.height) * 3;
    const time_step: f32 = 1.0 / @as(f32, @floatFromInt(fps));

    std.log.info("Generating video: {d}x{d}, variant {d}, {d} fps, {d} frames", .{
        args.width, args.height, args.variant, fps, total_frames,
    });

    const tic = std.time.microTimestamp();

    for (0..total_frames) |frame_idx| {
        const time: f32 = @as(f32, @floatFromInt(frame_idx)) * time_step;

        var data = try call_variant(allocator, args.variant, args.width, args.height, time);
        defer data.deinit(allocator);

        try stdout.writeAll(data.items[0..frame_size]);

        if (frame_idx % 10 == 0) {
            std.log.info("Frame {d}/{d}", .{ frame_idx, total_frames });
        }
    }

    const tac: i64 = std.time.microTimestamp() - tic;
    std.log.info("Video generated in {d:>20.2} s", .{@as(f32, @floatFromInt(tac)) / 1_000_000});
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // parse command line arguments
    const args = try cli.parse_args(allocator);

    switch (args.mode) {
        .image => |img| try generate_single_image(allocator, args, img.filename),
        .video => |vid| try generate_video(allocator, args, vid.fps, vid.total_frames),
    }
}

// Import tests from all modules
test {
    // Run tests from all submodules
    _ = cli;
    _ = simplex;
    _ = perlin;
    _ = variant1;
    _ = variant2;
    _ = variant3;
}

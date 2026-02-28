const std = @import("std");

pub const Mode = union(enum) {
    image: struct { filename: []const u8 },
    video: struct { fps: u32, total_frames: u32 },
};

pub const Params = struct {
    width: u32,
    height: u32,
    variant: u32,
    mode: Mode,
};

const ErrorCli = error{
    WrongArgument,
};

pub fn parse_args(allocator: std.mem.Allocator) !Params {
    std.log.debug("Parse command line arguments", .{});

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // skip executable name
    _ = args.skip();

    const first_arg = args.next();
    if (first_arg == null) {
        std.log.err("Missing filename or 'video' command", .{});
        return ErrorCli.WrongArgument;
    }

    const width_str = args.next();
    if (width_str == null) {
        std.log.err("Missing width", .{});
        return ErrorCli.WrongArgument;
    }
    const width = try std.fmt.parseInt(u32, width_str.?, 10);
    if (width == 0) {
        std.log.err("Invalid width", .{});
        return ErrorCli.WrongArgument;
    }
    const height_str = args.next();
    if (height_str == null) {
        std.log.err("Missing height", .{});
        return ErrorCli.WrongArgument;
    }
    const height = try std.fmt.parseInt(u32, height_str.?, 10);
    if (height == 0) {
        std.log.err("Invalid height", .{});
        return ErrorCli.WrongArgument;
    }

    const variant_str = args.next();
    if (variant_str == null) {
        std.log.err("Missing variant", .{});
        return ErrorCli.WrongArgument;
    }
    const variant = try std.fmt.parseInt(u32, variant_str.?, 10);
    if (variant == 0 or variant > 3) {
        std.log.err("Invalid variant version", .{});
        return ErrorCli.WrongArgument;
    }

    const is_image = !std.mem.eql(u8, first_arg.?, "video");

    if (is_image) {
        return Params{
            .width = width,
            .height = height,
            .variant = variant,
            .mode = .{ .image = .{ .filename = first_arg.? } },
        };
    }

    const fps_str = args.next();
    if (fps_str == null) {
        std.log.err("Missing fps", .{});
        return ErrorCli.WrongArgument;
    }
    const fps = try std.fmt.parseInt(u32, fps_str.?, 10);
    if (fps == 0) {
        std.log.err("Invalid fps", .{});
        return ErrorCli.WrongArgument;
    }

    const total_frames_str = args.next();
    if (total_frames_str == null) {
        std.log.err("Missing total_frames", .{});
        return ErrorCli.WrongArgument;
    }
    const total_frames = try std.fmt.parseInt(u32, total_frames_str.?, 10);
    if (total_frames == 0) {
        std.log.err("Invalid total_frames", .{});
        return ErrorCli.WrongArgument;
    }

    return Params{
        .width = width,
        .height = height,
        .variant = variant,
        .mode = .{ .video = .{ .fps = fps, .total_frames = total_frames } },
    };
}

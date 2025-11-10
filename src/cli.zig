const std = @import("std");

pub const Params = struct {
    filename: []const u8,
    width: u32,
    height: u32,
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

    const filename = args.next();
    if (filename == null) {
        std.log.err("Missing filename", .{});
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

    return Params{
        .filename = filename.?,
        .width = width,
        .height = height,
    };
}

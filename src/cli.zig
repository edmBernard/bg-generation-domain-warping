const std = @import("std");
const zyra = @import("zyra");

fn nonZero(value: u32) ?[]const u8 {
    return if (value == 0) "must be greater than 0" else null;
}

fn checkVariantRange(value: u32) ?[]const u8 {
    return if (value < 1 or value > 9) "must be between 1 and 9" else null;
}

pub const ImageArgs = struct {
    filename: []const u8,
    width: u32,
    height: u32,
    variant: u32,

    pub const zyra = .{
        .fields = .{
            .filename = .{ .help = "Output filename without extension (written as .jpeg)" },
            .width = .{ .help = "Image width in pixels", .validate = nonZero },
            .height = .{ .help = "Image height in pixels", .validate = nonZero },
            .variant = .{ .help = "Variant to generate (1-9)", .validate = checkVariantRange },
        },
    };
};

pub const VideoArgs = struct {
    width: u32,
    height: u32,
    variant: u32,
    fps: u32,
    total_frames: u32,

    pub const zyra = .{
        .fields = .{
            .width = .{ .help = "Frame width in pixels", .validate = nonZero },
            .height = .{ .help = "Frame height in pixels", .validate = nonZero },
            .variant = .{ .help = "Variant to generate (1-9)", .validate = checkVariantRange },
            .fps = .{ .help = "Frames per second", .validate = nonZero },
            .total_frames = .{ .help = "Number of frames to generate", .validate = nonZero },
        },
    };
};

pub const Command = union(enum) {
    image: ImageArgs,
    video: VideoArgs,

    pub const zyra = .{
        .name = "bg_generation",
        .about = "Generate background images or videos using domain warping.",
        .commands = .{
            .image = .{ .help = "Generate a single JPEG image" },
            .video = .{ .help = "Write raw RGB frames to stdout" },
        },
    };
};

const ErrorCli = error{
    WrongArgument,
    HelpRequested,
};

/// Parses the process arguments. On error, a diagnostic (or help) has already
/// been printed; `error.HelpRequested` signals a clean exit.
pub fn parse_args(init: std.process.Init) !Command {
    std.log.debug("Parse command line arguments", .{});

    var diagnostic: zyra.Diagnostic = undefined;
    const command = zyra.parseProcess(Command, init, .{
        .diagnostic = &diagnostic,
        .auto_help = true,
    }) catch |err| switch (err) {
        error.OutOfMemory => return err,
        error.HelpRequested => {
            var stdout_buffer: [1024]u8 = undefined;
            var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &stdout_buffer);
            const stdout = &stdout_file_writer.interface;
            try zyra.writeHelpForProcess(Command, init, stdout, .{});
            try stdout.flush();
            return ErrorCli.HelpRequested;
        },
        else => {
            var stderr_buffer: [1024]u8 = undefined;
            var stderr_file_writer: std.Io.File.Writer = .init(.stderr(), init.io, &stderr_buffer);
            const stderr = &stderr_file_writer.interface;
            try zyra.writeDiagnostic(diagnostic, stderr);
            try stderr.writeAll("\nTry 'bg_generation --help' for usage.\n");
            try stderr.flush();
            return ErrorCli.WrongArgument;
        },
    };

    return command;
}

test "parse image command" {
    const command = try zyra.parse(Command, &.{ "bg_generation", "image", "out", "1920", "1080", "3" }, .{});
    try std.testing.expectEqualStrings("out", command.image.filename);
    try std.testing.expectEqual(@as(u32, 1920), command.image.width);
    try std.testing.expectEqual(@as(u32, 1080), command.image.height);
    try std.testing.expectEqual(@as(u32, 3), command.image.variant);
}

test "parse video command with named arguments" {
    const command = try zyra.parse(Command, &.{ "bg_generation", "video", "--fps", "30", "640", "480", "9", "300" }, .{});
    try std.testing.expectEqual(@as(u32, 640), command.video.width);
    try std.testing.expectEqual(@as(u32, 480), command.video.height);
    try std.testing.expectEqual(@as(u32, 9), command.video.variant);
    try std.testing.expectEqual(@as(u32, 30), command.video.fps);
    try std.testing.expectEqual(@as(u32, 300), command.video.total_frames);
}

test "reject invalid values" {
    try std.testing.expectError(error.MissingRequired, zyra.parse(Command, &.{ "bg_generation", "image", "out", "1920" }, .{}));
    try std.testing.expectError(error.InvalidValue, zyra.parse(Command, &.{ "bg_generation", "image", "out", "0", "1080", "3" }, .{}));
    try std.testing.expectError(error.InvalidValue, zyra.parse(Command, &.{ "bg_generation", "video", "640", "480", "10", "30", "300" }, .{}));
    try std.testing.expectError(error.InvalidValue, zyra.parse(Command, &.{ "bg_generation", "video", "--fps", "0", "640", "480", "9", "300" }, .{}));

    var diagnostic: zyra.Diagnostic = undefined;
    try std.testing.expectError(error.InvalidValue, zyra.parse(Command, &.{ "bg_generation", "image", "out", "1920", "1080", "10" }, .{ .diagnostic = &diagnostic }));
    try std.testing.expectEqualStrings("must be between 1 and 9", diagnostic.reason.?);
}

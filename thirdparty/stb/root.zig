const stb = @import("stb_c");

const Error = error{
    FailedToSaveInFile,
};

pub fn image_write(
    filename: [:0]const u8,
    data: []const u8,
    width: u32,
    height: u32,
) !void {
    const number_component = 3; // RGB
    const quality = 95;

    const result = stb.stbi_write_jpg(
        filename.ptr,
        @intCast(width),
        @intCast(height),
        number_component,
        data.ptr,
        quality,
    );
    if (result == 0) {
        return Error.FailedToSaveInFile;
    }
}

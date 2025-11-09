const stb_image_write = @cImport({
    @cDefine("STB_IMAGE_WRITE_IMPLEMENTATION", "1");
    @cInclude("stb_image_write.h");
});

const Error = error{
    FailedToSaveInFile,
};

pub fn image_write(
    filename: []const u8,
    data: []const u8,
    width: u32,
    height: u32,
) !void {
    const number_component = 3; // RGB
    const quality = 95;

    const result = stb_image_write.stbi_write_jpg(
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

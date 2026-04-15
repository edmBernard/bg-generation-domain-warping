const std = @import("std");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("thirdparty/stb/stb_image_write.h"),
        .target = target,
        .optimize = optimize,
    });

    const module = b.addModule("stb_wrapper", .{
        .root_source_file = b.path("thirdparty/stb/root.zig"),
        .imports = &.{
            .{ .name = "stb_c", .module = translate_c.createModule() },
        },
    });

    module.addCSourceFile(.{
        .file = b.path("thirdparty/stb/stb_image_write_impl.c"),
    });

    module.link_libc = true;
    return module;
}

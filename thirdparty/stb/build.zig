const std = @import("std");

const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const translate_c = b.dependency("translate_c", .{});
    const translator: Translator = .init(translate_c, .{
        .c_source_file = b.path("thirdparty/stb/stb_image_write.h"),
        .target = target,
        .optimize = optimize,
    });

    const module = b.addModule("stb_wrapper", .{
        .root_source_file = b.path("thirdparty/stb/root.zig"),
        .imports = &.{
            .{ .name = "stb_c", .module = translator.mod },
        },
    });

    module.addCSourceFile(.{
        .file = b.path("thirdparty/stb/stb_image_write_impl.c"),
    });

    module.link_libc = true;
    return module;
}

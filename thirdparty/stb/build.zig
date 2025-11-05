const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) *std.Build.Module {
    const module = b.addModule("stb_wrapper", .{
        .root_source_file = b.path("thirdparty/stb/root.zig"),
    });

    module.addIncludePath(b.path("thirdparty/stb"));

    module.link_libc = true;
    return module;
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const stb_wrapper = @import("thirdparty/stb/build.zig").build(b);

    const mod_linearalgebra = b.addModule("linearalgebra", .{
        .root_source_file = b.path("src/linearalgebra.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{},
    });

    const mod_pixel_processor = b.addModule("pixel_processor", .{
        .root_source_file = b.path("src/pixel_processor.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "linearalgebra", .module = mod_linearalgebra },
        },
    });

    const mod_simplex = b.addModule("simplex", .{
        .root_source_file = b.path("src/simplex.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "linearalgebra", .module = mod_linearalgebra },
        },
    });

    const mod_perlin = b.addModule("perlin", .{
        .root_source_file = b.path("src/perlin.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "linearalgebra", .module = mod_linearalgebra },
        },
    });

    const mod_main_variant1 = b.addModule("bg_generation_variant1", .{
        .root_source_file = b.path("src/variants/variant1.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "linearalgebra", .module = mod_linearalgebra },
            .{ .name = "pixel_processor", .module = mod_pixel_processor },
            .{ .name = "simplex", .module = mod_simplex },
            .{ .name = "perlin", .module = mod_perlin },
        },
    });
    const mod_main_variant2 = b.addModule("bg_generation_variant2", .{
        .root_source_file = b.path("src/variants/variant2.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "linearalgebra", .module = mod_linearalgebra },
            .{ .name = "pixel_processor", .module = mod_pixel_processor },
            .{ .name = "simplex", .module = mod_simplex },
            .{ .name = "perlin", .module = mod_perlin },
        },
    });

    const exe = b.addExecutable(.{
        .name = "bg_generation",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "bg_generation_variant1", .module = mod_main_variant1 },
                .{ .name = "bg_generation_variant2", .module = mod_main_variant2 },
                .{ .name = "stb_wrapper", .module = stb_wrapper },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Create tests for all modules
    const test_step = b.step("test", "Run tests");

    const mods = [_]*std.Build.Module{
        mod_linearalgebra,
        mod_pixel_processor,
        mod_simplex,
        mod_perlin,
        mod_main_variant1,
        mod_main_variant2,
        exe.root_module,
    };
    for (mods) |mod| {
        const mod_test = b.addTest(.{
            .root_module = mod,
        });
        const run_mod_test = b.addRunArtifact(mod_test);
        test_step.dependOn(&run_mod_test.step);
    }
}

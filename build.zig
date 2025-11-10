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

    const mod_simplex = b.addModule("simplex", .{
        .root_source_file = b.path("src/simplex.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "linearalgebra", .module = mod_linearalgebra },
        },
    });

    const mod_main = b.addModule("bg_generation", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "linearalgebra", .module = mod_linearalgebra },
            .{ .name = "simplex", .module = mod_simplex },
        },
    });

    const exe = b.addExecutable(.{
        .name = "bg_generation",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "bg_generation", .module = mod_main },
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
        mod_simplex,
        mod_main,
        exe.root_module,
    };
    for (mods) |mod| {
        const mod_test = b.addTest(.{
            .root_module = mod,
        });
        const run_mod_test = b.addRunArtifact(mod_test);
        test_step.dependOn(&run_mod_test.step);
    }
    // // Creates an executable that will run `test` blocks from the provided module.
    // // Here `mod` needs to define a target, which is why earlier we made sure to
    // // set the releative field.
    // const mod_tests = b.addTest(.{
    //     .root_module = mod_main,
    // });

    // // A run step that will run the test executable.
    // const run_mod_tests = b.addRunArtifact(mod_tests);

    // // Creates an executable that will run `test` blocks from the executable's
    // // root module. Note that test executables only test one module at a time,
    // // hence why we have to create two separate ones.
    // const exe_tests = b.addTest(.{
    //     .root_module = exe.root_module,
    // });

    // // A run step that will run the second test executable.
    // const run_exe_tests = b.addRunArtifact(exe_tests);

    // test_step.dependOn(&run_mod_tests.step);
    // test_step.dependOn(&run_exe_tests.step);
}

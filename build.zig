const Builder = @import("std").build.Builder;
const std = @import("std");

fn setDependencies(b: *Builder, step: *std.build.LibExeObjStep) void {
    step.linkSystemLibrary("c");
    step.linkSystemLibrary("SDL2");
    step.linkSystemLibrary("SDL2_image");
    step.linkSystemLibrary("SDL2_ttf");
    step.linkSystemLibrary("curl");
}

pub fn build(b: *Builder) void {
    b.installDirectory(.{
        .source_dir = "scripts",
        .install_dir = .{ .Bin = .{} },
        .install_subdir = "",
    });

    const exe = b.addExecutable("mepo", "src/main.zig");

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    exe.setTarget(target);
    exe.setBuildMode(mode);

    setDependencies(b, exe);

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run mepo");
    run_step.dependOn(&run_cmd.step);

    // Setup test
    const test_all_step = b.step("test", "Run all tests.");
    const run_tests = b.addTest("./src/test.zig");
    setDependencies(b, run_tests);
    test_all_step.dependOn(&run_tests.step);
}

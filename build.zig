const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;

fn setDependencies(step: *std.build.LibExeObjStep) void {
    step.linkSystemLibrary("c");
    step.linkSystemLibrary("SDL2");
    step.linkSystemLibrary("SDL2_gfx");
    step.linkSystemLibrary("SDL2_image");
    step.linkSystemLibrary("SDL2_ttf");
    step.linkSystemLibrary("curl");
}

pub fn build(b: *Builder) void {
    b.installDirectory(.{
        .source_dir = "scripts",
        .install_dir = .{ .bin = .{} },
        .install_subdir = "",
    });
    b.installFile("assets/mepo.desktop", "share/applications/mepo.desktop");
    b.installFile("assets/mepo.png", "share/icons/hicolor/512x512/apps/mepo.png");

    const exe = b.addExecutable("mepo", "src/main.zig");

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    exe.setTarget(target);
    exe.setBuildMode(mode);

    setDependencies(exe);

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run mepo");
    run_step.dependOn(&run_cmd.step);

    // Setup test
    const test_all_step = b.step("test", "Run all tests.");
    const run_tests = b.addTest("./src/test.zig");
    setDependencies(run_tests);
    test_all_step.dependOn(&run_tests.step);
}

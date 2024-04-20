const std = @import("std");

fn setDependencies(step: *std.Build.Step.Compile) void {
    step.linkSystemLibrary("c");
    step.linkSystemLibrary("SDL2");
    step.linkSystemLibrary("SDL2_gfx");
    step.linkSystemLibrary("SDL2_image");
    step.linkSystemLibrary("SDL2_ttf");
    step.linkSystemLibrary("curl");
}

pub fn build(b: *std.Build) void {
    b.installDirectory(.{
        .source_dir = .{ .path = "scripts" },
        .install_dir = .{ .bin = {} },
        .install_subdir = "",
    });
    b.installFile("assets/mepo.desktop", "share/applications/mepo.desktop");
    b.installFile("assets/mepo.png", "share/pixmaps/mepo.png");
    b.installFile("assets/mepo_128x128.png", "share/icons/hicolor/128x128/apps/mepo.png");
    b.installFile("assets/mepo_512x512.png", "share/icons/hicolor/512x512/apps/mepo.png");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "mepo",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    setDependencies(exe);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run mepo");
    run_step.dependOn(&run_cmd.step);

    // Setup test
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "./src/test.zig" },
        .target = target,
        .optimize = optimize,
    });
    setDependencies(tests);

    const run_tests = b.addRunArtifact(tests);
    const test_all_step = b.step("test", "Run all tests.");
    test_all_step.dependOn(&run_tests.step);
}

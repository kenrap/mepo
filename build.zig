const std = @import("std");

fn addTranslateCModules(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, mod: *std.Build.Module) void {
    const stubs = [_]struct {
        c_module: []const u8,
        pkg_configs: ?[]const []const u8 = null,
    }{
        .{ .c_module = "sdl", .pkg_configs = &.{ "sdl2", "SDL2_image", "SDL2_gfx", "SDL2_ttf" } },
        .{ .c_module = "spawn" },
        .{ .c_module = "wordexp" },
        .{ .c_module = "stdlib" },
        .{ .c_module = "curl", .pkg_configs = &.{"libcurl"} },
        .{ .c_module = "stdio" },
    };
    for (stubs) |stub| {
        const tc = b.addTranslateC(.{
            .root_source_file = b.path(b.fmt("src/c/{s}.c", .{stub.c_module})),
            .target = target,
            .optimize = optimize,
        });
        if (stub.pkg_configs) |pkg_configs| {
            for (pkg_configs) |pkg_config| tc.linkSystemLibrary(pkg_config, .{});
        }
        mod.addImport(stub.c_module, tc.createModule());
    }
}

pub fn build(b: *std.Build) void {
    b.installDirectory(.{
        .source_dir = b.path("scripts"),
        .install_dir = .{ .bin = {} },
        .install_subdir = "",
    });
    b.installFile("assets/mepo.desktop", "share/applications/mepo.desktop");
    b.installFile("assets/mepo.png", "share/pixmaps/mepo.png");
    b.installFile("assets/mepo_128x128.png", "share/icons/hicolor/128x128/apps/mepo.png");
    b.installFile("assets/mepo_512x512.png", "share/icons/hicolor/512x512/apps/mepo.png");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    addTranslateCModules(b, target, optimize, exe_root_module);
    const exe = b.addExecutable(.{
        .name = "mepo",
        .root_module = exe_root_module,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Run mepo");
    run_step.dependOn(&run_cmd.step);

    // Setup test
    const tests_root_module = b.createModule(.{
        .root_source_file = b.path("./src/test.zig"),
        .optimize = optimize,
        .target = target,
    });
    addTranslateCModules(b, target, optimize, tests_root_module);
    const tests = b.addTest(.{
        .root_module = tests_root_module,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_all_step = b.step("test", "Run all tests.");
    test_all_step.dependOn(&run_tests.step);
}

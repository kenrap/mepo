const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utilplatform = @import("../util/utilplatform.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");
const sdl = @import("../sdlshim.zig");

var set_cmd: []const u8 = undefined;

pub const spec = .{
    .name = "shellpipe",
    .desc = "Run a system (shell) command and pipe; STDOUT returned from command will be executed back as mepolang",
    // TODO: document ENV vars usable in shell scripts context
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "as_async", .desc = "Set to 1 to run asynchronously (e.g. don't wait for process to complete)" },
        .{ .tag = .Text, .name = "shell_statement", .desc = "Shell statement to execute" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const as_async = args[0].Number == 1;
    const cmd = args[1].Text;
    try shellpipe(mepo, as_async, cmd);
}

fn shellpipe(mepo: *Mepo, as_async: bool, cmd: []const u8) !void {
    set_cmd = cmd;

    if (as_async) {
        _ = sdl.SDL_CreateThread(
            run_shellpipe,
            "async_shellpipe_thread_numbertodo",
            mepo,
        );
    } else {
        _ = run_shellpipe(mepo);
    }
}

fn run_shellpipe(userdata: ?*anyopaque) callconv(.C) c_int {
    var mepo : *Mepo = @ptrCast(*Mepo, @alignCast(@alignOf(*Mepo), userdata.?));
    run_shellpipe_errorified(mepo) catch unreachable;
    return 0;
}

fn run_shellpipe_errorified(mepo: *Mepo) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    try mepo.update_debug_message(
        try std.fmt.allocPrint(arena.allocator(), "Shellpipe ({s}) in progress - run!", .{set_cmd}),
    );
    try mepo.blit();

    const env_vars = env_vars: {
        var v = try std.process.getEnvMap(arena.allocator());
        const bbox = mepo.bounding_box();

        // TODO: maybe this should be in seperate/helper fn?
        var cursor_x: c_int = undefined;
        var cursor_y: c_int = undefined;
        _ = sdl.SDL_GetMouseState(&cursor_x, &cursor_y);
        const cursor_lat = utilconversion.px_y_to_lat(mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), 2) + cursor_y, mepo.zoom);
        const cursor_lon = utilconversion.px_x_to_lon(mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), 2) + cursor_x, mepo.zoom);

        // Window and zoom info
        try v.put("MEPO_WIN_W", try std.fmt.allocPrint(arena.allocator(), "{d}", .{mepo.win_w}));
        try v.put("MEPO_WIN_H", try std.fmt.allocPrint(arena.allocator(), "{d}", .{mepo.win_h}));
        try v.put("MEPO_ZOOM", try std.fmt.allocPrint(arena.allocator(), "{d}", .{mepo.zoom}));

        // Center and bbox
        try v.put("MEPO_CENTER_LAT", try std.fmt.allocPrint(arena.allocator(), "{d}", .{mepo.lat}));
        try v.put("MEPO_CENTER_LON", try std.fmt.allocPrint(arena.allocator(), "{d}", .{mepo.lon}));
        try v.put("MEPO_TL_LAT", try std.fmt.allocPrint(arena.allocator(), "{d}", .{bbox.topleft_lat}));
        try v.put("MEPO_TL_LON", try std.fmt.allocPrint(arena.allocator(), "{d}", .{bbox.topleft_lon}));
        try v.put("MEPO_BR_LAT", try std.fmt.allocPrint(arena.allocator(), "{d}", .{bbox.bottomright_lat}));
        try v.put("MEPO_BR_LON", try std.fmt.allocPrint(arena.allocator(), "{d}", .{bbox.bottomright_lon}));

        // Cursor position
        try v.put("MEPO_CURSOR_LAT", try std.fmt.allocPrint(arena.allocator(), "{d}", .{cursor_lat}));
        try v.put("MEPO_CURSOR_LON", try std.fmt.allocPrint(arena.allocator(), "{d}", .{cursor_lon}));

        break :env_vars v;
    };

    const args = [_][]const u8{ "sh", "-c", set_cmd};
    const process_result = try std.ChildProcess.exec(.{
        .allocator = arena.allocator(),
        .argv = args[0..],
        .env_map = &env_vars,
        .max_output_bytes = 10000 * 1024,
    });
    const exitcode = process_result.term.Exited;
    try mepo.update_debug_message(
        try std.fmt.allocPrint(arena.allocator(), "Shellpipe ({s}) completed - execute, {d}!", .{ set_cmd, process_result.stdout.len }),
    );
    try mepo.blit();
    if (exitcode == 0) {
        try mepo.mepolang_execute(process_result.stdout);
        try mepo.update_debug_message(null);
    } else {
        utildbg.log("shellpipe error: exited with code {d}\n{s}", .{ exitcode, process_result.stderr });
        try mepo.update_debug_message(process_result.stderr);
    }
}

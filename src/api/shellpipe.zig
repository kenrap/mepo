const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utilplatform = @import("../util/utilplatform.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");
const sdl = @import("../sdlshim.zig");

const ShellpipeRequest = struct {
    mepo: *Mepo,
    cmd: []const u8,
};

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
    if (as_async) {
        var sp_req = try mepo.allocator.create(ShellpipeRequest);
        sp_req.cmd = try mepo.allocator.dupeZ(u8, cmd);
        sp_req.mepo = mepo;

        _ = sdl.SDL_CreateThread(
            async_shellpipe_run,
            "async_shellpipe",
            sp_req,
        );
    } else {
        try shellpipe_run(mepo, cmd, false);
    }
}

fn async_shellpipe_run(userdata: ?*anyopaque) callconv(.C) c_int {
    var shellpipe_request: *ShellpipeRequest = @ptrCast(*ShellpipeRequest, @alignCast(@alignOf(*ShellpipeRequest), userdata.?));
    // TODO: defer free cmd
    shellpipe_run(shellpipe_request.mepo, shellpipe_request.cmd, true) catch return 1;
    return 0;
}

fn shellpipe_run(mepo: *Mepo, cmd: []const u8, as_async: bool) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    if (as_async) mepo.idle_mutex.lock();
    defer {
        if (as_async) mepo.idle_mutex.unlock();
    }

    try mepo.update_debug_message(
        try std.fmt.allocPrint(arena.allocator(), "Shellpipe ({s}) in progress - run!", .{cmd}),
    );
    try refresh_ui(mepo, as_async);
    const env_vars = try get_env_vars(mepo, arena.allocator());

    const args = [_][]const u8{ "sh", "-c", cmd };
    const process_result = try std.ChildProcess.exec(.{
        .allocator = arena.allocator(),
        .argv = args[0..],
        .env_map = &env_vars,
        .max_output_bytes = 10000 * 1024,
    });
    const exitcode = process_result.term.Exited;
    try mepo.update_debug_message(
        try std.fmt.allocPrint(arena.allocator(), "Shellpipe ({s}) completed - execute, {d}!", .{ cmd, process_result.stdout.len }),
    );
    try refresh_ui(mepo, as_async);
    if (exitcode == 0) {
        try mepo.mepolang_execute(process_result.stdout);
        try mepo.update_debug_message(null);
    } else {
        utildbg.log("shellpipe error: exited with code {d}\n{s}", .{ exitcode, process_result.stderr });
        try mepo.update_debug_message(process_result.stderr);
    }
}

fn refresh_ui(mepo: *Mepo, as_async: bool) !void {
    if (as_async) utilsdl.sdl_push_resize_event() else try mepo.blit();
}

fn get_env_vars(mepo: *Mepo, allocator: std.mem.Allocator) !std.BufMap {
    var v = try std.process.getEnvMap(allocator);
    const bbox = mepo.bounding_box();

    // TODO: maybe this should be in seperate/helper fn?
    var cursor_x: c_int = undefined;
    var cursor_y: c_int = undefined;
    _ = sdl.SDL_GetMouseState(&cursor_x, &cursor_y);
    const cursor_lat = utilconversion.px_y_to_lat(mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), 2) + cursor_y, mepo.zoom);
    const cursor_lon = utilconversion.px_x_to_lon(mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), 2) + cursor_x, mepo.zoom);

    // Window and zoom info
    try v.put("MEPO_WIN_W", try std.fmt.allocPrint(allocator, "{d}", .{mepo.win_w}));
    try v.put("MEPO_WIN_H", try std.fmt.allocPrint(allocator, "{d}", .{mepo.win_h}));
    try v.put("MEPO_ZOOM", try std.fmt.allocPrint(allocator, "{d}", .{mepo.zoom}));

    // Center and bbox
    try v.put("MEPO_CENTER_LAT", try std.fmt.allocPrint(allocator, "{d}", .{mepo.lat}));
    try v.put("MEPO_CENTER_LON", try std.fmt.allocPrint(allocator, "{d}", .{mepo.lon}));
    try v.put("MEPO_TL_LAT", try std.fmt.allocPrint(allocator, "{d}", .{bbox.topleft_lat}));
    try v.put("MEPO_TL_LON", try std.fmt.allocPrint(allocator, "{d}", .{bbox.topleft_lon}));
    try v.put("MEPO_BR_LAT", try std.fmt.allocPrint(allocator, "{d}", .{bbox.bottomright_lat}));
    try v.put("MEPO_BR_LON", try std.fmt.allocPrint(allocator, "{d}", .{bbox.bottomright_lon}));

    // Cursor position
    try v.put("MEPO_CURSOR_LAT", try std.fmt.allocPrint(allocator, "{d}", .{cursor_lat}));
    try v.put("MEPO_CURSOR_LON", try std.fmt.allocPrint(allocator, "{d}", .{cursor_lon}));

    return v;
}

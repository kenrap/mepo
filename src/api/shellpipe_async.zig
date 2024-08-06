const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utilplatform = @import("../util/utilplatform.zig");
const utilprocess = @import("../util/utilprocess.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");
const p = @import("../util/utilprefs.zig");
const sdl = @import("../sdlshim.zig");

const AsyncShellpipeRequest = struct {
    mepo: *Mepo,
    unique_handle_id: i8,
    cmd: []const u8,
};

pub const spec = .{
    .name = "shellpipe_async",
    .desc = "Run a system (shell) command and pipe asynchronously; STDOUT returned from command will be executed back as a jsonapi expression.",
    .args = &.{
        .{ .tag = .Number, .name = "unique_handle_id", .desc = "Optional id to deduplicate individual async shellpipe requests", .default_value = .{ .Number = 1 } },
        .{ .tag = .Text, .name = "shellcode", .desc = "Shell statement to execute" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try async_shellpipe(mepo, @intFromFloat(args[0].Number), args[1].Text);
}

fn async_shellpipe(mepo: *Mepo, unique_handle_id: i8, cmd: []const u8) !void {
    var sp_req = try mepo.allocator.create(AsyncShellpipeRequest);
    sp_req.unique_handle_id = unique_handle_id;
    sp_req.cmd = try mepo.allocator.dupe(u8, cmd);
    sp_req.mepo = mepo;
    sdl.SDL_DetachThread(sdl.SDL_CreateThread(async_shellpipe_run, "async_shellpipe", sp_req));
}

fn async_shellpipe_run(userdata: ?*anyopaque) callconv(.C) c_int {
    const shellpipe_request: *AsyncShellpipeRequest = @alignCast(@ptrCast(userdata.?));
    const mepo = shellpipe_request.mepo;
    defer mepo.allocator.destroy(shellpipe_request);
    const unique_handle_id = shellpipe_request.unique_handle_id;
    run_shellpipe(mepo, unique_handle_id, shellpipe_request.cmd) catch |err| {
        utildbg.log("Error running async shellpipe: {}\n", .{err});
    };
    _ = mepo.shellpipe_async_threads.swapRemove(unique_handle_id);
    return 0;
}

/// Spawn given command and wait for its output from another thread.
/// If async_id is null (i.e. called from shellpipe_sync), signal the UI
/// to soft-block until the command completes or is canceled.
pub fn run_shellpipe(mepo: *Mepo, async_id: ?i8, cmd: []const u8) !void {
    defer mepo.allocator.free(cmd);
    if (async_id) |unique_handle_id| {
        if (mepo.shellpipe_async_threads.get(unique_handle_id)) |thread_id| {
            utildbg.log("Async shellpipe id {} already present with thread ID {}\n", .{ unique_handle_id, thread_id });
            return;
        }
        try mepo.shellpipe_async_threads.put(unique_handle_id, sdl.SDL_GetThreadID(null));
    }

    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();
    const env_vars = try get_env_vars(mepo, arena.allocator());

    if (try utilprocess.run_subprocess(
        arena.allocator(),
        cmd,
        &env_vars,
        if (async_id == null) &mepo.shellpipe_sync_pid else null,
    )) |response_stdout| {
        const heap_stdout = try mepo.allocator.dupeZ(u8, response_stdout);
        utilsdl.sdl_push_event_jsonapi_execution(heap_stdout);
    }
}

fn get_env_vars(mepo: *Mepo, allocator: std.mem.Allocator) !std.process.EnvMap {
    var v = try std.process.getEnvMap(allocator);

    // Window and zoom info
    try v.put("MEPO_WIN_W", try std.fmt.allocPrint(allocator, "{d}", .{mepo.win_w}));
    try v.put("MEPO_WIN_H", try std.fmt.allocPrint(allocator, "{d}", .{mepo.win_h}));
    try v.put("MEPO_ZOOM", try std.fmt.allocPrint(allocator, "{d}", .{p.get(p.pref.zoom).u}));

    // Center position
    try v.put("MEPO_CENTER_LAT", try std.fmt.allocPrint(allocator, "{d}", .{p.get(p.pref.lat).f}));
    try v.put("MEPO_CENTER_LON", try std.fmt.allocPrint(allocator, "{d}", .{p.get(p.pref.lon).f}));

    // Bbox
    const bbox = mepo.bounding_box();
    try v.put("MEPO_TL_LAT", try std.fmt.allocPrint(allocator, "{d}", .{bbox.topleft_lat}));
    try v.put("MEPO_TL_LON", try std.fmt.allocPrint(allocator, "{d}", .{bbox.topleft_lon}));
    try v.put("MEPO_BR_LAT", try std.fmt.allocPrint(allocator, "{d}", .{bbox.bottomright_lat}));
    try v.put("MEPO_BR_LON", try std.fmt.allocPrint(allocator, "{d}", .{bbox.bottomright_lon}));

    // Cursor position
    const cursor_latlon = mepo.cursor_latlon();
    try v.put("MEPO_CURSOR_LAT", try std.fmt.allocPrint(allocator, "{d}", .{cursor_latlon.Lat}));
    try v.put("MEPO_CURSOR_LON", try std.fmt.allocPrint(allocator, "{d}", .{cursor_latlon.Lon}));

    // Pin metadata
    try v.put("MEPO_PINGROUPACTIVE", try std.fmt.allocPrint(allocator, "{d}", .{mepo.pin_group_active}));

    return v;
}

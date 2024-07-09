const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utilplatform = @import("../util/utilplatform.zig");
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
    sp_req.cmd = try mepo.allocator.dupeZ(u8, cmd);
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
    _ = mepo.async_shellpipe_threads.swapRemove(unique_handle_id);
    return 0;
}

/// Spawn given command and wait for its output from another thread.
/// If async_id is null (i.e. called from shellpipe_sync), signal the UI
/// to soft-block until the command completes or is canceled.
pub fn run_shellpipe(mepo: *Mepo, async_id: ?i8, cmd: []const u8) !void {
    defer mepo.allocator.free(cmd);
    if (async_id) |unique_handle_id| {
        if (mepo.async_shellpipe_threads.get(unique_handle_id)) |thread_id| {
            utildbg.log("Async shellpipe id {} already present with thread ID {}\n", .{ unique_handle_id, thread_id });
            return;
        }
        try mepo.async_shellpipe_threads.put(unique_handle_id, sdl.SDL_GetThreadID(null));
    }

    // More or less from zig 0.9 stdlib child process's spawnPosix
    const argv = [_][]const u8{ "sh", "-c", cmd };
    const max_output_bytes: usize = 50 * 1024;
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();
    var child = std.process.Child.init(argv[0..], arena.allocator());
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    const env = try get_env_vars(mepo, mepo.allocator);
    child.env_map = &env;
    child.pgid = 0; // create new process group
    try child.spawn();
    if (async_id == null)
        mepo.sync_shellpipe_pid = child.id;
    var stdout = std.ArrayList(u8).init(mepo.allocator);
    errdefer stdout.deinit();

    var poll_fds = [_]std.posix.pollfd{
        .{ .fd = child.stdout.?.handle, .events = std.posix.POLL.IN, .revents = undefined },
    };
    const bump_amt = 512;

    var continue_reading = true;
    while (continue_reading) {
        const events = try std.posix.poll(&poll_fds, std.math.maxInt(i32));
        if (events == 0) continue;
        if (poll_fds[0].revents & std.posix.POLL.IN != 0) {
            try stdout.ensureTotalCapacity(@min(stdout.items.len + bump_amt, max_output_bytes));
            if (stdout.unusedCapacitySlice().len == 0) return error.StdoutStreamTooLong;
            const nread = try std.posix.read(poll_fds[0].fd, stdout.unusedCapacitySlice());
            if (nread == 0) {
                continue_reading = false;
                continue;
            }
            stdout.items.len += nread;

            // Note: this is defacto broken since update from mepolang to JSON
            // api since semicolon (;) can no longer be used as delimiter.
            // TODO - will replace this bit with a single sync/noncontinual
            // implementation
            if (std.mem.lastIndexOf(u8, stdout.items, ";")) |jsonapi_statement_end_index| {
                const statement = stdout.items[0 .. jsonapi_statement_end_index + 1];
                utildbg.log("Running jsonapi statement from async shellpipe: {s}\n", .{statement});
                const heap_statement = try mepo.allocator.dupeZ(u8, statement);
                utilsdl.sdl_push_event_jsonapi_execution(heap_statement);
                try stdout.replaceRange(0, jsonapi_statement_end_index + 1, &[_]u8{});
            }
        } else if (poll_fds[0].revents & (std.posix.POLL.ERR | std.posix.POLL.NVAL | std.posix.POLL.HUP) != 0) {
            continue_reading = false;
            continue;
        }
    }
    _ = try child.kill();
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

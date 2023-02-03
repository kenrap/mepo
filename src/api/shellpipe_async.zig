const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utilplatform = @import("../util/utilplatform.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");
const p = @import("../util/utilprefs.zig");
const sdl = @import("../sdlshim.zig");
const get_env_vars = @import("./shellpipe_sync.zig").get_env_vars;

const AsyncShellpipeRequest = struct {
    mepo: *Mepo,
    unique_handle_id: i8,
    cmd: []const u8,
};

pub const spec = .{
    .name = "shellpipe_async",
    .desc = "Run a system (shell) command and pipe asynchronously; STDOUT returned from command will be executed back as a mepolang expression.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "unique_handle_id", .desc = "Optional id to deduplicate individual async shellpipe requests" },
        .{ .tag = .Text, .name = "shell_statement", .desc = "Shell statement to execute" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const unique_handle_id = @floatToInt(i8, args[0].Number);
    const cmd = args[1].Text;
    try async_shellpipe(mepo, unique_handle_id, cmd);
}

fn async_shellpipe(mepo: *Mepo, unique_handle_id: i8, cmd: []const u8) !void {
    var sp_req = try mepo.allocator.create(AsyncShellpipeRequest);
    sp_req.unique_handle_id = unique_handle_id;
    sp_req.cmd = try mepo.allocator.dupeZ(u8, cmd);
    sp_req.mepo = mepo;
    _ = sdl.SDL_CreateThread(async_shellpipe_run, "async_shellpipe", sp_req);
}

fn async_shellpipe_run(userdata: ?*anyopaque) callconv(.C) c_int {
    var shellpipe_request: *AsyncShellpipeRequest = @ptrCast(*AsyncShellpipeRequest, @alignCast(@alignOf(*AsyncShellpipeRequest), userdata.?));
    async_shellpipe_run_catch_errors(shellpipe_request.mepo, shellpipe_request.unique_handle_id, shellpipe_request.cmd) catch |err| {
        utildbg.log("Error running async shellpipe: {}\n", .{err});
    };
    return 0;
}

fn async_shellpipe_run_catch_errors(mepo: *Mepo, unique_handle_id: i8, cmd: []const u8) !void {
    defer mepo.allocator.free(cmd);
    const thread_id = sdl.SDL_GetThreadID(null);
    if (mepo.async_shellpipe_threads.get(unique_handle_id)) |already_spawned_thread_id| {
        utildbg.log("Async shellpipe id {} already present with thread_id {}\n", .{ unique_handle_id, already_spawned_thread_id });
        return;
    }
    try mepo.async_shellpipe_threads.put(unique_handle_id, thread_id);

    // More or less from zig 0.9 stdlib child process's spawnPosix
    const argv = [_][]const u8{ "sh", "-c", cmd };
    const max_output_bytes: usize = 50 * 1024;
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();
    var child = std.ChildProcess.init(argv[0..], arena.allocator());
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    const env = try get_env_vars(mepo, mepo.allocator);
    child.env_map = &env;
    try child.spawn();
    var stdout = std.ArrayList(u8).init(mepo.allocator);
    errdefer stdout.deinit();

    var poll_fds = [_]std.os.pollfd{
        .{ .fd = child.stdout.?.handle, .events = std.os.POLL.IN, .revents = undefined },
    };
    const bump_amt = 512;

    var continue_reading = true;
    while (continue_reading) {
        const events = try std.os.poll(&poll_fds, std.math.maxInt(i32));
        if (events == 0) continue;
        if (poll_fds[0].revents & std.os.POLL.IN != 0) {
            try stdout.ensureTotalCapacity(std.math.min(stdout.items.len + bump_amt, max_output_bytes));
            if (stdout.unusedCapacitySlice().len == 0) return error.StdoutStreamTooLong;
            const nread = try std.os.read(poll_fds[0].fd, stdout.unusedCapacitySlice());
            if (nread == 0) {
                continue_reading = false;
                continue;
            }
            stdout.items.len += nread;
            if (std.mem.lastIndexOf(u8, stdout.items, ";")) |mepolang_statement_end_index| {
                const statement = stdout.items[0 .. mepolang_statement_end_index + 1];
                utildbg.log("Running mepolang statement from async shellpipe: {s}\n", .{statement});
                var heap_statement = try mepo.allocator.dupeZ(u8, statement);
                utilsdl.sdl_push_event_mepolang_execution(heap_statement);
                try stdout.replaceRange(0, mepolang_statement_end_index + 1, &[_]u8{});
            }
        } else if (poll_fds[0].revents & (std.os.POLL.ERR | std.os.POLL.NVAL | std.os.POLL.HUP) != 0) {
            continue_reading = false;
            continue;
        }
    }
    _ = try child.kill();
    _ = mepo.async_shellpipe_threads.swapRemove(unique_handle_id);
}

const c = @import("spawn");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");

// Executes the command cmd with environment variables in env_map.
// When spawned without any error, returns null if the process terminates early,
// otherwise stdout captured in a slice owned by the caller.
//
// Note: zig stdlib spawning (std.process.Child based impl) is avoided here
// as zig doesn't support pgid for spawned processes. See:
//   - https://lists.sr.ht/~mil/mepo-devel/%3C20240709141534.516065-1-cnx@loang.net%3E
//   - https://github.com/ziglang/zig/pull/20556
//
pub fn run_subprocess(
    allocator: std.mem.Allocator,
    io: std.Io,
    cmd: []const u8,
    env_map: *const std.process.Environ.Map,
    set_process_id_opt_ptr_opt: ?*?std.posix.pid_t,
) !?[]const u8 {
    var pid: std.c.pid_t = undefined;
    defer {
        if (set_process_id_opt_ptr_opt) |pid_ptr|
            pid_ptr.* = null;
    } // Stop blocking the UI

    var actions: c.posix_spawn_file_actions_t = undefined;
    if (c.posix_spawn_file_actions_init(&actions) != 0)
        return error.PosixSpawnFileActionsInitFailed;
    defer if (c.posix_spawn_file_actions_destroy(&actions) != 0) unreachable;
    var pipe: [2]std.posix.system.fd_t = undefined;
    switch (std.posix.errno(std.posix.system.pipe(&pipe))) {
        .SUCCESS => {},
        else => |other| {
            return std.posix.unexpectedErrno(other);
        },
    }
    errdefer _ = std.posix.system.close(pipe[0]);
    errdefer _ = std.posix.system.close(pipe[1]);
    // The read end of the pipe is unused by the spawned process.
    if (c.posix_spawn_file_actions_addclose(&actions, pipe[0]) != 0)
        return error.PosixSpawnFileActionsAddCloseFailed;
    // Redirect stdout to the write end of the pipe.
    if (c.posix_spawn_file_actions_adddup2(&actions, pipe[1], 1) != 0)
        return error.PosixSpawnFileActionsAddDup2Failed;

    var attr: c.posix_spawnattr_t = undefined;
    if (c.posix_spawnattr_init(&attr) != 0)
        return error.PosixSpawnAttrInitFailed;
    defer if (c.posix_spawnattr_destroy(&attr) != 0) unreachable;
    const flags = c.POSIX_SPAWN_SETSIGMASK |
        c.POSIX_SPAWN_SETSIGDEF |
        c.POSIX_SPAWN_SETPGROUP;
    if (c.posix_spawnattr_setflags(&attr, flags) != 0)
        return error.PosixSpawnAttrSetFlagsFailed;
    if (c.posix_spawnattr_setpgroup(&attr, 0) != 0)
        return error.PosixSpawnAttrSetPgroupFailed;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const args = [_:null]?[*:0]u8{
        (try alloc.dupeSentinel(u8, "sh", 0)).ptr,
        (try alloc.dupeSentinel(u8, "-c", 0)).ptr,
        (try std.fmt.allocPrintSentinel(alloc, "exec {s}", .{cmd}, 0)).ptr,
    };
    const env_vars = try env_map.createPosixBlock(alloc, .{});
    defer env_vars.deinit(alloc);
    if (c.posix_spawnp(&pid, "sh", &actions, &attr, &args, @ptrCast(env_vars.slice)) != 0)
        return error.PosixSpawnFailed;
    // The write end of the pipe is unused by this parent process.
    _ = std.posix.system.close(pipe[1]);
    if (set_process_id_opt_ptr_opt) |pid_ptr|
        pid_ptr.* = pid;

    const stdout = blk: {
        defer _ = std.posix.system.close(pipe[0]);
        const file = std.Io.File{ .handle = pipe[0], .flags = .{ .nonblocking = false } };
        var read_buffer: [4096]u8 = undefined;
        var reader = file.reader(io, &read_buffer);
        break :blk try reader.interface.allocRemaining(allocator, .limited(10_000_000));
    };
    var status: c_int = undefined;
    _ = std.posix.system.waitpid(pid, &status, 0);
    // Spawn failure of foreign binaries are reported as successful:
    // https://github.com/ziglang/zig/pull/14866
    // TODO: mention this in user documentation.
    if (status == 0) return stdout;
    allocator.free(stdout);
    utildbg.log("Early termination of spawned process (via signal, stopped, etc.): {s}\n", .{cmd});
    return null;
}

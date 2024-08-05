const c = @cImport({
    @cInclude("spawn.h");
});
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");

// Executes the command cmd with environment variables in env_map.
// When spawned without any error, returns null if the process terminates early,
// otherwise stdout captured in a slice owned by the caller.
pub fn run_subprocess(
    allocator: std.mem.Allocator,
    cmd: []const u8,
    env_map: *const std.process.EnvMap,
    set_process_id_opt_ptr_opt: ?*?std.process.Child.Id,
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
    const pipe = try std.posix.pipe();
    errdefer std.posix.close(pipe[0]);
    errdefer std.posix.close(pipe[1]);
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
    const args = [_:null]?[*:0]u8{
        (try arena.allocator().dupeZ(u8, "sh")).ptr,
        (try arena.allocator().dupeZ(u8, "-c")).ptr,
        (try std.fmt.allocPrintZ(arena.allocator(), "exec {s}", .{cmd})).ptr,
    };
    const env_vars = try std.process.createEnvironFromMap(arena.allocator(), env_map, .{});
    if (c.posix_spawnp(&pid, "sh", &actions, &attr, &args, env_vars.ptr) != 0)
        return error.PosixSpawnFailed;
    // The write end of the pipe is unused by this parent process.
    std.posix.close(pipe[1]);
    if (set_process_id_opt_ptr_opt) |pid_ptr|
        pid_ptr.* = pid;

    const file = std.fs.File{ .handle = pipe[0] };
    const stdout = try file.readToEndAlloc(allocator, 10_000_000);
    std.posix.close(pipe[0]);
    const result = std.posix.waitpid(pid, 0);
    // Spawn failure of foreign binaries are reported as successful:
    // https://github.com/ziglang/zig/pull/14866
    // TODO: mention this in user documentation.
    if (result.status == 0) return stdout;
    allocator.free(stdout);
    utildbg.log("Early termination of spawned process (via signal, stopped, etc.): {s}\n", .{cmd});
    return null;
}

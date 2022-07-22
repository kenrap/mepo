const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const csignal = @cImport({
    @cInclude("signal.h");
});

pub const spec = .{
    .name = "shellpipe_async_kill",
    .desc = "Kill an async shellpipe process",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "unique_handle_id", .desc = "Id of shellpipe process to kill, or -1 to kill all shellpipe processes" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const unique_handle_id = @floatToInt(i8, args[0].Number);
    try async_shellpipe_kill(mepo, unique_handle_id);
}

fn async_shellpipe_kill(mepo: *Mepo, unique_handle_id: i8) !void {
    const kill_sig = 15; // E.g. SIGTERM

    if (unique_handle_id == -1) {
        var it = mepo.async_shellpipe_threads.iterator();
        while (it.next()) |kv| {
            const thread_process_id = @ptrCast(*csignal.pthread_t, kv.value_ptr).*;
            _ = csignal.pthread_kill(thread_process_id, kill_sig);
        }
        mepo.async_shellpipe_threads.clearAndFree();
    } else if (mepo.async_shellpipe_threads.getPtr(unique_handle_id)) |thread_process_id_uncasted| {
        const thread_process_id = @ptrCast(*csignal.pthread_t, thread_process_id_uncasted).*;
        _ = csignal.pthread_kill(thread_process_id, kill_sig);
        _ = mepo.async_shellpipe_threads.swapRemove(unique_handle_id);
    }
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");

const AsyncShellpipeRequest = struct {
    mepo: *Mepo,
    unique_handle_id: i8,
    cmd: []const u8,
};

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
    _ = mepo;
    _ = unique_handle_id;
}

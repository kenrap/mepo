const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .args = (&[_]types.MepoArgTag{ .Text, .Text })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const signo = args[0].Text;
    const expression = args[1].Text;
    try bind_signal(mepo, signo, expression);
}

fn bind_signal(mepo: *Mepo, signo_str: [:0]const u8, expression: []const u8) !void {
    utildbg.log("Binding signal: signo={s} to expression {s}\n", .{ signo_str, expression });

    // Signal
    var signo: u6 = 0;
    if (std.cstr.cmp(signo_str, "USR1") == 0) {
        signo = std.os.SIG.USR1;
    } else if (std.cstr.cmp(signo_str, "USR2") == 0) {
        signo = std.os.SIG.USR2;
    } else {
        return error.InvalidSignalName;
    }

    // Register generic signal handler
    if (0 != std.os.linux.sigaction(signo, &.{
        .handler = .{ .handler = Mepo.sighandle_user },
        .mask = [_]u32{0} ** 32,
        .flags = @as(c_uint, 0),
    }, null)) {
        return error.FailedToSetupSighandler;
    }

    if (mepo.table_signals.get(signo)) |heap_str| {
        mepo.allocator.free(heap_str);
        _ = mepo.table_signals.swapRemove(signo);
    }
    const expression_heap_allocated = try mepo.allocator.dupe(u8, expression);
    try mepo.table_signals.put(signo, expression_heap_allocated);
}

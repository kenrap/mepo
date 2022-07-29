const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");

pub const spec = .{
    .name = "bind_signal",
    .desc = "Bind a signal to execute a mepolang action",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "signal_name", .desc = "Signal name; can be `USR1`, `USR2`, `TERM`, or `INT`" },
        .{ .tag = .Text, .name = "mepolang_expression", .desc = "Mepolang expression to run" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const signal_name = args[0].Text;
    const expression = args[1].Text;
    try bind_signal(mepo, signal_name, expression);
}

fn bind_signal(mepo: *Mepo, signo_str: [:0]const u8, expression: []const u8) !void {
    utildbg.log("Binding signal: signal_name={s} to expression {s}\n", .{ signo_str, expression });

    // Signal
    var signal_name: u6 = 0;
    if (std.cstr.cmp(signo_str, "USR1") == 0) {
        signal_name = std.os.SIG.USR1;
    } else if (std.cstr.cmp(signo_str, "USR2") == 0) {
        signal_name = std.os.SIG.USR2;
    } else if (std.cstr.cmp(signo_str, "TERM") == 0) {
        signal_name = std.os.SIG.TERM;
    } else if (std.cstr.cmp(signo_str, "INT") == 0) {
        signal_name = std.os.SIG.INT;
    } else {
        return error.InvalidSignalName;
    }

    // Register generic signal handler
    if (0 != std.os.linux.sigaction(signal_name, &.{
        .handler = .{ .handler = utilsdl.sdl_push_event_signal },
        .mask = [_]u32{0} ** 32,
        .flags = @as(c_uint, 0),
    }, null)) {
        return error.FailedToSetupSighandler;
    }

    if (mepo.table_signals.get(signal_name)) |heap_str| {
        mepo.allocator.free(heap_str);
        _ = mepo.table_signals.swapRemove(signal_name);
    }
    const expression_heap_allocated = try mepo.allocator.dupe(u8, expression);
    try mepo.table_signals.put(signal_name, expression_heap_allocated);
}

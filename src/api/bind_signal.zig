const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");

pub const spec = types.MepoFnSpec{
    .name = "bind_signal",
    .desc = "Bind a signal to execute JSON API expressions.",
    .args = &.{
        .{ .tag = .Text, .name = "sig", .desc = "Signal name; can be `USR1`, `USR2`, `TERM`, or `INT`" },
        .{ .tag = .Exps, .name = "exps", .desc = "JSON API expressions to run" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const signal_name = args[0].Text;
    const expression = args[1].Exps;
    try bind_signal(mepo, signal_name, expression);
}

fn bind_signal(mepo: *Mepo, signo_str: [:0]const u8, expression: []const u8) !void {
    utildbg.log("Binding signal: signal_name={s} to expression {s}\n", .{ signo_str, expression });

    // Signal
    var signal_name: u6 = 0;
    if (std.mem.orderZ(u8, signo_str, "USR1") == .eq) {
        signal_name = std.os.linux.SIG.USR1;
    } else if (std.mem.orderZ(u8, signo_str, "USR2") == .eq) {
        signal_name = std.os.linux.SIG.USR2;
    } else if (std.mem.orderZ(u8, signo_str, "TERM") == .eq) {
        signal_name = std.os.linux.SIG.TERM;
    } else if (std.mem.orderZ(u8, signo_str, "INT") == .eq) {
        signal_name = std.os.linux.SIG.INT;
    } else {
        return error.InvalidSignalName;
    }

    // Register generic signal handler
    const signal_action = std.posix.Sigaction{
        .handler = .{ .handler = utilsdl.sdl_push_event_signal },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    };

    std.posix.sigaction(signal_name, &signal_action, null);

    if (mepo.table_signals.get(signal_name)) |heap_str| {
        mepo.allocator.free(heap_str);
        _ = mepo.table_signals.swapRemove(signal_name);
    }
    const expression_heap_allocated = try mepo.allocator.dupe(u8, expression);
    try mepo.table_signals.put(signal_name, expression_heap_allocated);
}

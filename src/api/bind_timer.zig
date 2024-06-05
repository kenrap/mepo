const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");

pub const spec = .{
    .name = "bind_timer",
    .desc = "Bind a timer to execute a mepolang action at the given interval.",
    .args = &.{
        .{ .tag = .Number, .name = "interval_seconds", .desc = "Number of seconds between successive runs of given mepolang expression" },
        .{ .tag = .Text, .name = "mepolang_expression", .desc = "Mepolang expression to run" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try bind_timer(mepo, @intFromFloat(args[0].Number), args[1].Text);
}

fn bind_timer(mepo: *Mepo, interval_seconds: u32, expression: []const u8) !void {
    utildbg.log("Binding timer: interval seconds={d} to expression {s}\n", .{ interval_seconds, expression });

    const expression_heap_allocated = try mepo.allocator.dupe(u8, expression);
    const timer: types.TimerInput = .{
        .interval_seconds = interval_seconds,
        .created_at_ticks = sdl.SDL_GetTicks(),
    };

    try mepo.table_timers.put(timer, expression_heap_allocated);
}

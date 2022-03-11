const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub fn f_bind_gesture(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const action : types.GestureInputAction = if (std.mem.eql(u8, args[0].Text, "pan")) .Pan else .Rotate;
    const direction : types.GestureInputDirection = if (args[1].Number == -1) .In else .Out;
    const expression = args[2].Text;
    try bind_gesture(mepo, action, direction, expression);
}

fn bind_gesture(mepo: *Mepo, action: types.GestureInputAction, direction: types.GestureInputDirection, expression: []const u8) !void {
    utildbg.log("Binding gesture: action={} direction={} to expression {s}\n", .{ action, direction, expression });

    const gest = .{
        .action = action,
        .direction = direction,
    };

    if (mepo.table_gestures.get(gest)) |heap_str| {
        mepo.allocator.free(heap_str);
        _ = mepo.table_gestures.swapRemove(gest);
    }
    const expression_mepo_allocated = try mepo.allocator.dupe(u8, expression);
    try mepo.table_gestures.put(gest, expression_mepo_allocated);
}

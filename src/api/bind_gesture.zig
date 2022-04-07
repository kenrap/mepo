const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .name = "bind_gesture",
    .desc = "Bind a multitouch gesture event to execute a mepolang action",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "action", .desc = "Gesture action (set to either `pan` or `rotate`)" },
        .{ .tag = .Number, .name = "fingers", .desc = "Number of fingers to trigger expression" },
        .{ .tag = .Number, .name = "direction", .desc = "Direction for gesture (e.g. `1` for in or `2` for out)" },
        .{ .tag = .Text, .name = "mepolang_expression", .desc = "Mepolang expression to run" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const action: types.GestureInputAction = if (std.mem.eql(u8, args[0].Text, "pan")) .Pan else .Rotate;
    const fingers: u8 = @floatToInt(u8, args[1].Number);
    const direction: types.GestureInputDirection = if (args[2].Number == 1) .In else .Out;
    const expression = args[3].Text;
    try bind_gesture(mepo, action, fingers, direction, expression);
}

fn bind_gesture(mepo: *Mepo, action: types.GestureInputAction, fingers: u8, direction: types.GestureInputDirection, expression: []const u8) !void {
    utildbg.log("Binding gesture: fingers={} action={} direction={} to expression {s}\n", .{ fingers, action, direction, expression });

    const gest = .{
        .n_fingers = fingers,
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

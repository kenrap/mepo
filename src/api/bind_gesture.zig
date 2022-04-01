const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .args = (&[_]types.MepoArgTag{ .Text, .Number, .Number, .Text })[0..],
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

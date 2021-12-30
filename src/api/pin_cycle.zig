const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_cycle(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const delta = @floatToInt(i32, args[0].Number);
    try pin_cycle(mepo, delta);
}

fn pin_cycle(mepo: *Mepo, delta: i32) !void {
    const add : i32 = if (delta > 0) 1 else -1;

    var delta_current = delta;
    while (delta_current != 0) : (delta_current -= add) {
        var pin_i: i32 = undefined;
        if (mepo.pin_groups[mepo.pin_group_active].pins.items.len == 0)
            return
        else if (mepo.pin_group_active_item == null)
            pin_i = 0
        else
            pin_i = @intCast(i32, mepo.pin_group_active_item.?) + add;

        while (pin_i > -1 and
            mepo.pin_groups[mepo.pin_group_active].pins.items.len > pin_i and
            mepo.pin_groups[mepo.pin_group_active].pins.items[@intCast(usize, pin_i)].category == .Structural)
            pin_i += add;

        if (pin_i > -1 and mepo.pin_groups[mepo.pin_group_active].pins.items.len > pin_i)
            mepo.pin_group_active_item = @intCast(u32, pin_i);
    }
}

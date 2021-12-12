const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_cycle(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const delta = @floatToInt(i32, args[0].Number);
    const center_pin = args[1].Number > 0;
    try pin_cycle(mepo, delta, center_pin);
}

fn pin_cycle(mepo: *Mepo, delta: i32, center_pin: bool) !void {
    if ((mepo.pin_group_active_item == null and mepo.pin_groups[mepo.pin_group_active].pins.items.len > 0) or
        (mepo.pin_group_active_item != null and @intCast(i32, mepo.pin_group_active_item.?) + delta >= @intCast(i32, mepo.pin_groups[mepo.pin_group_active].pins.items.len)))
    {
        mepo.pin_group_active_item = 0;
    } else if (mepo.pin_group_active_item != null and @intCast(i32, mepo.pin_group_active_item.?) + delta < 0) {
        mepo.pin_group_active_item = @intCast(u32, mepo.pin_groups[mepo.pin_group_active].pins.items.len - 1);
    } else if (mepo.pin_group_active_item != null) {
        mepo.pin_group_active_item.? = @intCast(u32, @intCast(i32, mepo.pin_group_active_item.?) + delta);
    }

    if (center_pin and mepo.pin_group_active_item != null) {
        const pin = mepo.pin_groups[mepo.pin_group_active].pins.items[mepo.pin_group_active_item.?];
        mepo.lat = pin.lat;
        mepo.lon = pin.lon;
    }
}

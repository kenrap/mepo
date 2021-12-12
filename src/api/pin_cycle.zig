const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_cycle(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const index = @floatToInt(i32, args[0].Number);
    const center_pin = args[1].Number > 0;
    try pin_cycle(mepo, index, center_pin);
}

fn pin_cycle(mepo: *Mepo, index: i32, center_pin: bool) !void {
    if ((mepo.pin_group_active_item == null and mepo.pin_groups[mepo.pin_group_active].pins.items.len > 0) or
        (mepo.pin_group_active_item != null and mepo.pin_group_active_item.? + 1 == mepo.pin_groups[mepo.pin_group_active].pins.items.len))
    {
        mepo.pin_group_active_item = 0;
    } else if (mepo.pin_group_active_item != null) {
        mepo.pin_group_active_item.? += 1;
    }

    if (center_pin and mepo.pin_group_active_item != null) {
        const pin = mepo.pin_groups[mepo.pin_group_active].pins.items[mepo.pin_group_active_item.?];
        mepo.lat = pin.lat;
        mepo.lon = pin.lon;
    }
}

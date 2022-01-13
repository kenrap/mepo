const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_center_on_pin(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    try center_on_pin(mepo);
}

fn center_on_pin(mepo: *Mepo) !void {
    if (mepo.pin_group_active_item != null) {
        const pin = mepo.pin_groups[mepo.pin_group_active].pins.items[mepo.pin_group_active_item.?];
        mepo.lat = pin.lat;
        mepo.lon = pin.lon;
    }
}

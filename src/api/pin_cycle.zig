const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_cycle(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const delta = @floatToInt(i32, args[0].Number);
    const center_pin = args[1].Number > 0;
    try pin_cycle(mepo, delta, center_pin);
}

fn pin_cycle(mepo: *Mepo, delta: i32, center_pin: bool) !void {
    if (delta != 1 and delta != -1)
        return error.OnlyOneUnitDeltaSupportedForNow;

    var pin_i: i32 = undefined;
    if (mepo.pin_groups[mepo.pin_group_active].pins.items.len == 0)
        return
    else if (mepo.pin_group_active_item == null)
        pin_i = 0
    else
        pin_i = @intCast(i32, mepo.pin_group_active_item.?) + delta;

    while (pin_i > -1 and
        mepo.pin_groups[mepo.pin_group_active].pins.items.len > pin_i and
        mepo.pin_groups[mepo.pin_group_active].pins.items[@intCast(usize, pin_i)].category == .Structural)
        pin_i += delta;

    if (pin_i > -1 and mepo.pin_groups[mepo.pin_group_active].pins.items.len > pin_i)
        mepo.pin_group_active_item = @intCast(u32, pin_i);

    if (center_pin and mepo.pin_group_active_item != null) {
        const pin = mepo.pin_groups[mepo.pin_group_active].pins.items[mepo.pin_group_active_item.?];
        mepo.lat = pin.lat;
        mepo.lon = pin.lon;
    }
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_cycle",
    .args = (&[_]types.MepoArgTag{ .Number, .Number })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const viewport_only = @floatToInt(i32, args[0].Number) == 1;
    const delta = @floatToInt(i32, args[1].Number);
    try pin_cycle(mepo, viewport_only, delta);
}

pub fn pin_cycle(mepo: *Mepo, viewport_only: bool, delta: i32) !void {
    if (mepo.pin_groups[mepo.pin_group_active].pins.items.len == 0) return;

    const add: i32 = if (delta > 0) 1 else -1;
    var delta_current = delta;
    while (delta_current != 0) : (delta_current -= add) {
        var pin_i: i32 = undefined;

        pin_i = if (mepo.pin_group_active_item == null) 0 else @intCast(i32, mepo.pin_group_active_item.?) + add;

        // E.g. two conditions to skip and continually increase pin_i:
        // 1. Within an ordered group, structural pins should be skipped
        // 2. Requested to cycle only viewport visible pins, non visible pins skipped
        while (pin_i > -1 and pin_i < mepo.pin_groups[mepo.pin_group_active].pins.items.len and
            ((mepo.pin_groups[mepo.pin_group_active].ordered and mepo.pin_groups[mepo.pin_group_active].pins.items[@intCast(usize, pin_i)].category == .Structural) or
            (viewport_only and !pin_in_viewport(mepo, pin_i))))
            pin_i += add;

        if (pin_i > -1 and
            mepo.pin_groups[mepo.pin_group_active].pins.items.len > pin_i and
            (!viewport_only or (viewport_only and pin_in_viewport(mepo, pin_i))))
            mepo.pin_group_active_item = @intCast(u32, pin_i);
    }
}

fn pin_in_viewport(mepo: *Mepo, pin_index: i32) bool {
    const pin = mepo.pin_groups[mepo.pin_group_active].pins.items[@intCast(usize, pin_index)];
    const x = mepo.convert_latlon_to_xy(.LonToX, pin.lon);
    const y = mepo.convert_latlon_to_xy(.LatToY, pin.lat);
    return x > 0 and x < mepo.win_w and y > 0 and y < mepo.win_h;
}

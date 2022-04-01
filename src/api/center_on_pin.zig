const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "center_on_pin",
    .args = (&[_]types.MepoArgTag{})[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    if (mepo.pin_group_active_item != null) {
        const pin = mepo.pin_groups[mepo.pin_group_active].pins.items[mepo.pin_group_active_item.?];
        mepo.lat = pin.lat;
        mepo.lon = pin.lon;
    }
}

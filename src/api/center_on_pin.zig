const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const p = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "center_on_pin",
    .desc = "Center the map on the currently active pin.",
    .args = (&[_]types.MepoFnSpecArg{})[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    if (mepo.pin_group_active_item != null) {
        const pin = mepo.pin_groups[mepo.pin_group_active].items[mepo.pin_group_active_item.?];
        p.set_n(p.pref.lat, pin.lat);
        p.set_n(p.pref.lon, pin.lon);
    }
}

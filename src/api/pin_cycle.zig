const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const center_on_coords = @import("./center_on_coords.zig");

pub fn f_pin_cycle(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const index = @floatToInt(i32, args[0].Number);
    try pin_cycle(mepo, index);
}

pub fn pin_cycle(mepo: *Mepo, index: i32) !void {
    var activeNext: bool = false;

    var it = mepo.pin_table.iterator();
    while (it.next()) |item| {
        if (activeNext) {
            mepo.pin_active = item.key_ptr.*;
            center_on_coords.center_on_coords(mepo, item.value_ptr.lat, item.value_ptr.lon);
            return;
        }
        if (mepo.pin_active != null and std.mem.eql(u8, mepo.pin_active.?, item.key_ptr.*)) {
            activeNext = true;
        }
    }

    if (mepo.pin_table.count() > 0) {
        const first = mepo.pin_table.iterator().next().?;
        mepo.pin_active = first.key_ptr.*;
        center_on_coords.center_on_coords(mepo, first.value_ptr.lat, first.value_ptr.lon);
    }
}

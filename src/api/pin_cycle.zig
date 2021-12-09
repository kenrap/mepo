const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_cycle(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const index = @floatToInt(i32, args[0].Number);
    const center_pin = args[1].Number > 0;
    try pin_cycle(mepo, index, center_pin);
}

fn pin_cycle(mepo: *Mepo, index: i32, center_pin: bool) !void {
    var active_next: bool = false;

    var it = mepo.pin_table.iterator();
    while (it.next()) |item| {
        if (active_next) {
            mepo.pin_active = item.key_ptr.*;
            if (center_pin) {
                mepo.lat = item.value_ptr.lat;
                mepo.lon = item.value_ptr.lon;
            }
            return;
        }
        if (mepo.pin_active != null and std.mem.eql(u8, mepo.pin_active.?, item.key_ptr.*)) {
            active_next = true;
        }
    }

    if (mepo.pin_table.count() > 0) {
        const first = mepo.pin_table.iterator().next().?;
        mepo.pin_active = first.key_ptr.*;
        if (center_pin) {
            mepo.lat = first.value_ptr.lat;
            mepo.lon = first.value_ptr.lon;
        }
    }
}

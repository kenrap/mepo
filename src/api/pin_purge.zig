const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_purge(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try pin_purge(mepo);
}

fn pin_purge(mepo: *Mepo) !void {
    mepo.pin_active = null;

    var pin_it = mepo.pin_table.iterator();
    while (pin_it.next()) |pin| {
        mepo.allocator.free(pin.key_ptr.*);
    }
    mepo.pin_table.clearAndFree();
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_purge(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    try pin_purge(mepo);
}

fn pin_purge(mepo: *Mepo) !void {
    mepo.pin_group_active_item = null;

    for (mepo.pin_groups[mepo.pin_group_active].pins.items) |p| {
        mepo.allocator.free(p.name);
        if (p.handle != null) mepo.allocator.free(p.handle.?);
    }
    mepo.pin_groups[mepo.pin_group_active].pins.clearAndFree();
}

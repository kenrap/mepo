const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_purge",
    .args = (&[_]types.MepoFnSpecArg{})[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    mepo.pin_group_active_item = null;

    for (mepo.pin_groups[mepo.pin_group_active].pins.items) |p| {
        mepo.allocator.free(p.name);
        if (p.handle != null) mepo.allocator.free(p.handle.?);
    }
    mepo.pin_groups[mepo.pin_group_active].pins.clearAndFree();
}

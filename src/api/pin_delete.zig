const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_delete",
    .args = (&[_]types.MepoFnSpecArg{
        .{.tag = .Text, .name = "pin_handle"},
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const handle = args[0].Text;
    try pin_delete(mepo, handle);
}

fn pin_delete(mepo: *Mepo, handle: [:0]const u8) !void {
    for (mepo.pin_groups[mepo.pin_group_active].pins.items) |pin, pin_i| {
        if (pin.handle == null) continue;

        if (std.mem.eql(u8, pin.handle.?, handle)) {
            mepo.allocator.free(pin.name);
            mepo.allocator.free(pin.handle.?);
            _ = mepo.pin_groups[mepo.pin_group_active].pins.orderedRemove(pin_i);
            return;
        }
    }
}

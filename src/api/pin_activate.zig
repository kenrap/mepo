const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_activate",
    .desc = "Activate a pin by its handle.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "group_number", .desc = "Group number" },
        .{ .tag = .Text, .name = "pin_handle", .desc = "Pin's handle to activate" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const group = @floatToInt(i32, args[0].Number);
    const handle = args[1].Text;
    try pin_activate(mepo, group, handle);
}

fn pin_activate(mepo: *Mepo, group: i32, handle: [:0]const u8) !void {
    const pin_group = if (group < 0) mepo.pin_group_active else @intCast(usize, group);

    for (mepo.pin_groups[pin_group].items) |*pin, pin_i| {
        if (pin.handle == null) continue;
        if (std.mem.eql(u8, pin.handle.?, handle)) {
            mepo.pin_group_active = @intCast(u8, pin_group);
            mepo.pin_group_active_item = @intCast(u32, pin_i);
        }
    }
}

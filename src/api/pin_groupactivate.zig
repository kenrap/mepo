const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const pin_cycle = @import("pin_cycle.zig").pin_cycle;

pub const spec = .{
    .name = "pin_groupactivate",
    .desc = "Activate the pin group specified.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "group_number", .desc = "Group number" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const group_number = @floatToInt(usize, args[0].Number);

    mepo.pin_group_active_item = null;
    mepo.pin_group_active = @intCast(u8, group_number);
    try pin_cycle(mepo, false, 1);
}

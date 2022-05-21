const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const pin_cycle = @import("pin_cycle.zig").pin_cycle;

pub const spec = .{
    .name = "pin_groupprefset_n",
    .desc = "Set a pin group's number preference",
    // TODO: figure out doc table/mapping here..
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "group_number", .desc = "The pin group number" },
        .{ .tag = .Text, .name = "prefrence_name", .desc = "Preference name" },
        .{ .tag = .Number, .name = "prefrence_value", .desc = "Preference number value" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const group_number = @floatToInt(usize, args[0].Number);
    const prefname = args[1].Text;
    const value = args[2].Number;

    if (std.mem.eql(u8, prefname, "ordered")) {
        mepo.pin_groups[group_number].ordered = value == 1;
    } else if (std.mem.eql(u8, prefname, "active") and value == 1) {
        mepo.pin_group_active_item = null;
        mepo.pin_group_active = @intCast(u8, group_number);
        try pin_cycle(mepo, false, 1);
    }
}

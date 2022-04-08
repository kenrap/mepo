const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const pin_cycle = @import("pin_cycle.zig").pin_cycle;

pub const spec = .{
    .name = "pin_groupprefset_t",
    .desc = "Set a pin group's text preference",
    // TODO: figure out doc table/mapping here..
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "group_number", .desc = "The pin group number" },
        .{ .tag = .Text, .name = "prefrence_name", .desc = "Preference name" },
        .{ .tag = .Text, .name = "prefrence_value", .desc = "Preference text value" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const group_number = @floatToInt(usize, args[0].Number);
    const prefname = args[1].Text;
    const value = args[2].Text;

    if (std.mem.eql(u8, prefname, "color")) {
        if (value.len < 1 or value[0] != '#') return error.InvalidColor;
        const color = try std.fmt.parseUnsigned(u24, value[1..], 16);
        mepo.pin_groups[group_number].color = color;
    }
}

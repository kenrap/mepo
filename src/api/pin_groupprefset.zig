const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_groupprefset(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const prefname = args[0].Text;
    const val = args[1].Text;

    if (std.mem.eql(u8, prefname, "color")) {
        if (args[1].Text.len < 1 or args[1].Text[0] != '#') return error.InvalidColor;
        const color = try std.fmt.parseUnsigned(u24, args[1].Text[1..], 16);
        mepo.pin_groups[mepo.pin_group_active].color = color;
    } else if (std.mem.eql(u8, prefname, "ordered")) {
        mepo.pin_groups[mepo.pin_group_active].ordered = args[1].Number == 1;
    }
}

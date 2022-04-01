const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const pin_cycle = @import("pin_cycle.zig").pin_cycle;
const utilarg = @import("../util/utilarg.zig");

pub const spec = .{
    .args = (&[_]types.MepoArgTag{ .Number, .Text })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const group_number = @floatToInt(usize, args[0].Number);
    const prefname = args[1].Text;

    if (std.mem.eql(u8, prefname, "color")) {
        if (args[2].Text.len < 1 or args[2].Text[0] != '#') return error.InvalidColor;
        const color = try std.fmt.parseUnsigned(u24, args[2].Text[1..], 16);
        mepo.pin_groups[group_number].color = color;
    } else if (std.mem.eql(u8, prefname, "ordered")) {
        mepo.pin_groups[group_number].ordered = args[2].Number == 1;
    } else if (std.mem.eql(u8, prefname, "visible")) {
        mepo.pin_groups[group_number].visible = args[2].Number == 1;
    } else if (std.mem.eql(u8, prefname, "active") and args[2].Number == 1) {
        mepo.pin_group_active_item = null;
        mepo.pin_group_active = @intCast(u8, group_number);
        try pin_cycle(mepo, false, 1);
    }
}

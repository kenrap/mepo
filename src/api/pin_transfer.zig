const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_transfer",
    .desc = "Transfer a pin from one group to another.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "from_group_number", .desc = "Group number" },
        .{ .tag = .Number, .name = "pin_handle", .desc = "Handle of the pin to transfer; if empty will transfer all pins." },
        .{ .tag = .Number, .name = "to_group_number", .desc = "Group number" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const from_group = @floatToInt(usize, args[0].Number);
    const pin_handle = args[1].Text;
    const to_group = @floatToInt(usize, args[2].Number);
    try pin_transfer(mepo, from_group, pin_handle, to_group);
}

fn pin_transfer(mepo: *Mepo, from_group: usize, pin_handle: [:0]const u8, to_group: usize) !void {
    for (mepo.pin_groups[from_group].items) |pin, pin_i| {
        if (pin.handle) |handle| {
            if (std.mem.eql(u8, handle, pin_handle)) {
                try mepo.pin_groups[to_group].append(pin);
                _ = mepo.pin_groups[from_group].orderedRemove(pin_i);
                return;
            }
        }
    }
}

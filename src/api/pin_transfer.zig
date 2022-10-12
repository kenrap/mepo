const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_transfer",
    .desc = "Transfer a pin from one group to another.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "from_group_number", .desc = "Group number, or -1 for the current group number" },
        .{ .tag = .Text, .name = "pin_handle", .desc = "Handle of the pin to transfer; if empty will transfer the current pin." },
        .{ .tag = .Number, .name = "to_group_number", .desc = "Group number" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const from_group = @floatToInt(i32, args[0].Number);
    const pin_handle = args[1].Text;
    const to_group = @floatToInt(usize, args[2].Number);
    try pin_transfer(mepo, from_group, pin_handle, to_group);
}

fn pin_transfer(mepo: *Mepo, from_group_number: i32, target_pin_handle: [:0]const u8, to_group: usize) !void {
    const from_group = if (from_group_number < 0) mepo.pin_group_active else @intCast(usize, from_group_number);
    const from_pin_i = from_pin_i: {
        if (target_pin_handle.len == 0) {
            if (mepo.pin_group_active_item) |active_item| {
                break :from_pin_i active_item;
            }
        } else {
            for (mepo.pin_groups[from_group].items) |pin, pin_i| {
                if (pin.handle) |handle| {
                    if (std.mem.eql(u8, handle, target_pin_handle)) {
                        break :from_pin_i pin_i;
                    }
                }
            }
        }
        return;
    };

    try mepo.pin_groups[to_group].append(mepo.pin_groups[from_group].items[from_pin_i]);
    _ = mepo.pin_groups[from_group].orderedRemove(from_pin_i);
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_delete",
    .desc = "Delete a pin by its handle.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "group_number", .desc = "Group number" },
        .{ .tag = .Text, .name = "pin_handle", .desc = "Pin's handle to delete" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const group = @floatToInt(i32, args[0].Number);
    const handle = args[1].Text;
    try pin_delete(mepo, group, handle);
}

fn pin_delete(mepo: *Mepo, group: i32, handle: [:0]const u8) !void {
    const pin_group = if (group < 0) mepo.pin_group_active else @intCast(usize, group);

    for (mepo.pin_groups[pin_group].items) |*pin, pin_i| {
        if (pin.handle == null) continue;

        if (std.mem.eql(u8, pin.handle.?, handle)) {
            // Free up handle string
            mepo.allocator.free(pin.handle.?);

            // Free up metadata strings
            var it = pin.metadata.iterator();
            while (it.next()) |kv| {
                mepo.allocator.free(kv.key_ptr.*);
                mepo.allocator.free(kv.value_ptr.*);
            }

            // If deleting currently active pin, clear out the active item index as well
            if (pin_group == mepo.pin_group_active) {
                if (mepo.pin_group_active_item) |active_pin_item| {
                    if (active_pin_item == pin_i) {
                        mepo.pin_group_active_item = null;
                    }
                }
            }

            _ = mepo.pin_groups[pin_group].orderedRemove(pin_i);
            return;
        }
    }
}

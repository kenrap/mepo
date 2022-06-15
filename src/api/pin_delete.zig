const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_delete",
    .desc = "Delete a pin by its handle",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "pin_handle", .desc = "Pin's handle to delete" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const handle = args[0].Text;
    try pin_delete(mepo, handle);
}

fn pin_delete(mepo: *Mepo, handle: [:0]const u8) !void {
    for (mepo.pin_groups[mepo.pin_group_active].items) |*pin, pin_i| {
        if (pin.handle == null) continue;

        if (std.mem.eql(u8, pin.handle.?, handle)) {
            mepo.allocator.free(pin.handle.?);

            var it = pin.metadata.iterator();
            while (it.next()) |kv| {
                mepo.allocator.free(kv.key_ptr.*);
                mepo.allocator.free(kv.value_ptr.*);
            }

            if (mepo.pin_group_active_item) |active_pin_item| {
                if (active_pin_item == pin_i) {
                    mepo.pin_group_active_item = null;
                }
            }
            _ = mepo.pin_groups[mepo.pin_group_active].orderedRemove(pin_i);

            return;
        }
    }
}

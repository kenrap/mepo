const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_meta",
    .args = (&[_]types.MepoFnSpecArg{
        .{.tag = .Number, .name = "group_number"},
        .{.tag = .Text, .name = "pin_handle"},
        .{.tag = .Text, .name = "key"},
        .{.tag = .Text, .name = "value"},
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const group = @floatToInt(i32, args[0].Number);
    const handle = args[1].Text;
    const key = args[2].Text;
    const value = args[3].Text;
    try pin_meta(mepo, group, handle, key, value);
}

pub fn pin_meta(mepo: *Mepo, group: i32, handle: [:0]const u8, key: [:0]const u8, value: [:0]const u8) !void {
    const pin_group = if (group < 0) mepo.pin_group_active else @intCast(usize, group);

    var pin: *types.Pin = pin: {
        for (mepo.pin_groups[pin_group].pins.items) |*pin| {
            if (pin.handle != null and std.mem.eql(u8, pin.handle.?, handle)) {
                break :pin pin;
            }
        }
        return;
    };

    if (pin.metadata.get(key)) |old_value| mepo.allocator.free(old_value);

    if (value.len == 0) {
        _ = pin.metadata.swapRemove(key);
    } else {
        const heap_key = try mepo.allocator.dupeZ(u8, key);
        const heap_val = try mepo.allocator.dupeZ(u8, value);
        try pin.metadata.put(heap_key, heap_val);
    }
}

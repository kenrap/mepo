const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_meta",
    .desc = "Update a pin's metadata.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "group_number", .desc = "Group number" },
        .{ .tag = .Text, .name = "pin_handle", .desc = "Pin handle" },
        .{ .tag = .Text, .name = "key", .desc = "Metadata key to update" },
        .{ .tag = .Text, .name = "value", .desc = "New value for metadata key" },
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
        for (mepo.pin_groups[pin_group].items) |*pin| {
            if (pin.handle != null and std.mem.eql(u8, pin.handle.?, handle)) {
                break :pin pin;
            }
        }
        return;
    };

    if (pin.metadata.get(key)) |old_value| mepo.allocator.free(old_value);

    if (value.len == 0) {
        _ = pin.metadata.swapRemove(key);
    } else if (std.mem.eql(u8, "lat", key)) {
        pin.lat = try std.fmt.parseFloat(f64, value);
    } else if (std.mem.eql(u8, "lon", key)) {
        pin.lon = try std.fmt.parseFloat(f64, value);
    } else {
        const heap_key = try mepo.allocator.dupeZ(u8, key);
        const heap_val = try mepo.allocator.dupeZ(u8, value);
        try pin.metadata.put(heap_key, heap_val);
    }
}

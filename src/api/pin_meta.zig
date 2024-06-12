const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_meta",
    .desc = "Update a pin's metadata.",
    .args = &.{
        .{ .tag = .Number, .name = "group", .desc = "Group number", .default_value = .{ .Number = -1 } },
        .{ .tag = .Text, .name = "handle", .desc = "Pin handle" },
        .{ .tag = .Text, .name = "key", .desc = "Metadata key to update" },
        .{ .tag = .Text, .name = "value", .desc = "New value for metadata key" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try pin_meta(mepo, @intFromFloat(args[0].Number), args[1].Text, args[2].Text, args[3].Text);
}

pub fn pin_meta(mepo: *Mepo, group: i32, handle: [:0]const u8, key: [:0]const u8, value: [:0]const u8) !void {
    const pin_group: usize = if (group < 0) mepo.pin_group_active else @intCast(group);

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

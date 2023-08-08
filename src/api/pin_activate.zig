const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_activate",
    .desc = "Activate a pin by its handle.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "group_number", .desc = "Group number" },
        .{ .tag = .Text, .name = "pin_handle", .desc = "Pin's handle to activate" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try pin_activate(mepo, @intFromFloat(args[0].Number), args[1].Text);
}

fn pin_activate(mepo: *Mepo, group: i32, handle: [:0]const u8) !void {
    const pin_group: usize = if (group < 0) mepo.pin_group_active else @intCast(group);
    defer mepo.blit_pinlayer_cache.clearAndFree();

    for (mepo.pin_groups[pin_group].items, 0..) |*pin, pin_i| {
        if (pin.handle == null) continue;
        if (std.mem.eql(u8, pin.handle.?, handle)) {
            mepo.pin_group_active = @intCast(pin_group);
            mepo.pin_group_active_item = @intCast(pin_i);
        }
    }
}

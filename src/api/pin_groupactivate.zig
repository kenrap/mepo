const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const pin_cycle = @import("pin_cycle.zig").pin_cycle;

pub const spec = types.MepoFnSpec{
    .name = "pin_groupactivate",
    .desc = "Activate the pin group specified.",
    .args = &.{
        .{ .tag = .Number, .name = "group", .desc = "Group number" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    defer mepo.blit_pinlayer_cache.clearAndFree();
    mepo.pin_group_active_item = null;
    mepo.pin_group_active = @intFromFloat(args[0].Number);
    try pin_cycle(mepo, false, 1);
}

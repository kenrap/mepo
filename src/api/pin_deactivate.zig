const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = types.MepoFnSpec{
    .name = "pin_deactivate",
    .desc = "Deactivate currently active pin.",
    .args = &.{},
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    mepo.pin_group_active_item = null;
    mepo.blit_pinlayer_cache.clearAndFree();
}

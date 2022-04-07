const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_deactivate",
    .desc = "Deactivate currently active pin",
    .args = (&[_]types.MepoFnSpecArg{})[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    mepo.pin_group_active_item = null;
}

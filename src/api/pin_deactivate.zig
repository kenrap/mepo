const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_deactivate(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try pin_deactivate(mepo);
}

fn pin_deactivate(mepo: *Mepo) !void {
    mepo.pin_active = null;
}

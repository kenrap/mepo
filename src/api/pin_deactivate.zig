const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const center_on_coords = @import("./center_on_coords.zig");

pub fn f_pin_deactivate(mepo: *Mepo, args: [5]types.MepoArg) !void {
    try pin_deactivate(mepo);
}

pub fn pin_deactivate(mepo: *Mepo) !void {
  mepo.pin_active = null;
}

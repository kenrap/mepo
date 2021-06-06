const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const center_on_coords = @import("./center_on_coords.zig");

pub fn f_pin_purge(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try pin_purge(mepo);
}

pub fn pin_purge(mepo: *Mepo) !void {
  mepo.pin_active = null;
  mepo.pin_table.clearAndFree();
}

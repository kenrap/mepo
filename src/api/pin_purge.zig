const Fmap = @import("../Fmap.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const center_on_coords = @import("./center_on_coords.zig");

pub fn f_pin_purge(fmap: *Fmap, args: [5]types.MepoArg) !void {
    try pin_purge(fmap);
}

pub fn pin_purge(fmap: *Fmap) !void {
  fmap.pin_active = null;
  fmap.pin_table.clearAndFree();
}

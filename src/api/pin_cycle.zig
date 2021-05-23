const Fmap = @import("../Fmap.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const center_on_coords = @import("./center_on_coords.zig");

pub fn f_pin_cycle(fmap: *Fmap, args: [5]types.MepoArg) !void {
    const index = @floatToInt(i32, args[0].Number);
    try pin_cycle(fmap, index);
}

pub fn pin_cycle(fmap: *Fmap, index: i32) !void {
  var activeNext : bool = false;
  for (fmap.pin_table.items()) |item| {
    if (activeNext) {
      fmap.pin_active = item.key;
      center_on_coords.center_on_coords(fmap, item.value.lat, item.value.lon);
      return;
    }
    if (fmap.pin_active != null and std.mem.eql(u8, fmap.pin_active.?, item.key)) {
      activeNext = true;
    }
  }

  if (fmap.pin_table.items().len > 0) {
    fmap.pin_active = fmap.pin_table.items()[0].key;
    center_on_coords.center_on_coords(fmap, fmap.pin_table.items()[0].value.lat, fmap.pin_table.items()[0].value.lon);
  }
}

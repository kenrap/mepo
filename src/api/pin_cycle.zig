const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const center_on_coords = @import("./center_on_coords.zig");

pub fn f_pin_cycle(mepo: *Mepo, args: [5]types.MepoArg) !void {
    const index = @floatToInt(i32, args[0].Number);
    try pin_cycle(mepo, index);
}

pub fn pin_cycle(mepo: *Mepo, index: i32) !void {
  var activeNext : bool = false;
  for (mepo.pin_table.items()) |item| {
    if (activeNext) {
      mepo.pin_active = item.key;
      center_on_coords.center_on_coords(mepo, item.value.lat, item.value.lon);
      return;
    }
    if (mepo.pin_active != null and std.mem.eql(u8, mepo.pin_active.?, item.key)) {
      activeNext = true;
    }
  }

  if (mepo.pin_table.items().len > 0) {
    mepo.pin_active = mepo.pin_table.items()[0].key;
    center_on_coords.center_on_coords(mepo, mepo.pin_table.items()[0].value.lat, mepo.pin_table.items()[0].value.lon);
  }
}

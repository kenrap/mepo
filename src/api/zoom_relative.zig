const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const center_on_coords = @import("./center_on_coords.zig");

pub fn f_zoom_relative(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const relative = @floatToInt(i32, args[0].Number);
    zoom_relative(mepo, relative);
}

pub fn zoom_relative(mepo: *Mepo, relative: i32) void {
  var old_lat = conversionutil.px_y_to_lat(mepo.y, mepo.zoom);
  var old_lon = conversionutil.px_x_to_lon(mepo.x, mepo.zoom);
  mepo.zoom = @intCast(u8, @intCast(i32, mepo.zoom) + relative);
  center_on_coords.center_on_coords(mepo, old_lat, old_lon);
}

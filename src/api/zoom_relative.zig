const Fmap = @import("../Fmap.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const center_on_coords = @import("./center_on_coords.zig");

pub fn f_zoom_relative(fmap: *Fmap, args: [5]types.MepoArg) !void {
    const relative = @floatToInt(i32, args[0].Number);
    zoom_relative(fmap, relative);
}

pub fn zoom_relative(fmap: *Fmap, relative: i32) void {
  var old_lat = conversionutil.px_to_lat(fmap.y, fmap.zoom);
  var old_lon = conversionutil.px_to_lon(fmap.x, fmap.zoom);
  fmap.zoom = @intCast(u8, @intCast(i32, fmap.zoom) + relative);
  center_on_coords.center_on_coords(fmap, old_lat, old_lon);
}

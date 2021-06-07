const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const config = @import("../config.zig");

pub fn f_download_bbox(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const a_lat = args[0].Number;
    const a_lon = args[1].Number;
    const b_lat = args[2].Number;
    const b_lon = args[3].Number;
    const zoom_min = @floatToInt(i32, args[4].Number);
    const zoom_max = @floatToInt(i32, args[5].Number);

    try download_bbox(mepo, a_lat, a_lon, b_lat, b_lon, zoom_min, zoom_max);
}

pub fn download_bbox(mepo: *Mepo, a_lat: f64, a_lon: f64, b_lat: f64, b_lon: f64, zoom_min: i32, zoom_max: i32) !void {
  const lat_min = if (a_lat < b_lat) a_lat else b_lat;
  const lat_max = if (a_lat > b_lat) a_lat else b_lat;
  const lon_min = if (a_lon < b_lon) a_lon else b_lon;
  const lon_max = if (a_lon > b_lon) a_lon else b_lon;

  var z: u32 = @intCast(u32, zoom_min);
  while (z <= zoom_max) : (z += 1) {
    const x_min = @divFloor(conversionutil.lon_to_px_x(lon_min, z), config.Tsize);
    const x_max = @divFloor(conversionutil.lon_to_px_x(lon_max, z), config.Tsize);
    const y_min = @divFloor(conversionutil.lat_to_px_y(lat_max, z), config.Tsize);
    const y_max = @divFloor(conversionutil.lat_to_px_y(lat_min, z), config.Tsize);
    var x : i32 = x_min;
    while (x <= x_max) : (x += 1) {
      var y : i32 = y_min;
      while (y <= y_max) : (y += 1) {
        std.debug.warn("Queue {d} {d} {d}\n", .{x, y, z});
        try mepo.tile_cache.tile_queue_no_surface_load(.{
            .x = @intCast(u32, x),
            .y = @intCast(u32, y),
            .z = @intCast(u8, z)
        });
      }
    }
  }
}

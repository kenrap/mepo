const std = @import("std");
const cstd = @cImport({
  @cInclude("stdlib.h");
});
const types = @import("../types.zig");

pub fn parse_string_latlon(latlon_str: []const u8) !types.Latlon {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    var lat : ?f64 = null;
    var lon: ?f64 = null;

    var n = try std.cstr.addNullByte(&arena.allocator, latlon_str);
    var p : *u8 = &n[0];
    while (p.* != 0) {
      if (p.* == '-' or std.ascii.isDigit(p.*)) {
        var val = @floatCast(f64, cstd.strtod(p, @ptrCast([*c][*c]u8, &p)));
        if (lat == null) {
          lat = val;
        } else if (lon == null) {
          lon = val;
          break;
        }
      }
      p = @intToPtr(*u8, @ptrToInt(p) + 1);
    }

    if (lat == null or lon == null) {
        return error.FailedToParseLatLon;
    }

    if (std.mem.count(u8, latlon_str, "W") > 0 or std.mem.count(u8, latlon_str, "W") > 0) {
      lon.? *= -1;
    }

    var latlon = .{
        .lat = lat.?,
        .lon = lon.?
    };

    return latlon;
}

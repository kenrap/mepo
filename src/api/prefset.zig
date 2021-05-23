const Fmap = @import("../Fmap.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const center_on_coords = @import("./center_on_coords.zig");

pub fn f_prefset(fmap: *Fmap, args: [5]types.MepoArg) !void {
    const name = args[0].Text;

    if (std.mem.eql(u8, "debug_global", name)) {
      fmap.debug_global = args[1].Number == 1;
    } else if (std.mem.eql(u8, "debug_tiles", name)) {
      fmap.debug_tiles = args[1].Number == 1;
    } else if (std.mem.eql(u8, "zoom", name)) {
      fmap.zoom = @floatToInt(u8, args[1].Number);
    } else if (std.mem.eql(u8, "crosshair_on", name)) {
      fmap.crosshair_on = args[1].Number == 1;
    } else if (std.mem.eql(u8, "crosshair_size", name)) {
      fmap.crosshair_size = @floatToInt(u8, args[1].Number);
    } else if (std.mem.eql(u8, "tile_cache_dir", name)) {
      try fmap.tile_cache.set_cache_dir(args[1].Text);
    } else if (std.mem.eql(u8, "tile_cache_url", name)) {
      try fmap.tile_cache.set_cache_url(args[1].Text);
    }
}

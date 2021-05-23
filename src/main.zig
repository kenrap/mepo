const std = @import("std");
const Fmap = @import("./Fmap.zig");
const TileCache = @import("./TileCache.zig");
const conversion = @import("./conversion.zig");
const sdl = @import("./sdlshim.zig");
const parseutil = @import("./util/parseutil.zig");
const stringsutil = @import("./util/stringsutil.zig");

pub fn main() !void {
  var cfg = try stringsutil.read_stdin();

  var tile_cache = try TileCache.init();
  var tile_download_thread = sdl.SDL_CreateThread(TileCache.download_loop_sdl_threadable, "Tile_Download_Thread", &tile_cache);
  var fmap = try Fmap.init(&tile_cache, cfg);
  try fmap.sdl_event_loop();
}

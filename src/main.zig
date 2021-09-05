const std = @import("std");
const Mepo = @import("./Mepo.zig");
const TileCache = @import("./TileCache.zig");
const conversion = @import("./conversion.zig");
const sdl = @import("./sdlshim.zig");
const parseutil = @import("./util/parseutil.zig");
const stringsutil = @import("./util/stringsutil.zig");

pub fn main() !void {
    var args = try stringsutil.read_args();

    var cfg: ?[]const u8 = cfg: {
        if (args.len > 0 and std.mem.eql(u8, args[0], "-i")) {
            break :cfg try stringsutil.read_stdin();
        } else {
            break :cfg null;
        }
    };

    var tile_cache = try TileCache.init();
    var tile_download_thread = sdl.SDL_CreateThread(TileCache.download_loop_sdl_threadable, "Tile_Download_Thread", &tile_cache);
    var mepo = try Mepo.init(&tile_cache, cfg);
    try mepo.sdl_event_loop();
}

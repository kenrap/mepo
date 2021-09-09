const std = @import("std");
const builtin = @import("builtin");
const Mepo = @import("./Mepo.zig");
const TileCache = @import("./TileCache.zig");
const conversion = @import("./conversion.zig");
const sdl = @import("./sdlshim.zig");
const parseutil = @import("./util/parseutil.zig");
const stringsutil = @import("./util/stringsutil.zig");

pub fn main() !void {
    comptime {
        if (std.SemanticVersion.order(builtin.zig_version, try std.SemanticVersion.parse("0.8.0")) != .eq) {
            @panic("Must be built against Zig 0.8.0");
        }
    }

    var allocator = std.heap.c_allocator;
    var args = try stringsutil.read_args(allocator);
    var cfg: ?[]const u8 = cfg: {
        if (args.len > 0 and std.mem.eql(u8, args[0], "-i")) {
            break :cfg try stringsutil.read_stdin(allocator);
        } else {
            break :cfg null;
        }
    };
    var tile_cache = try TileCache.init();
    var tile_download_thread = sdl.SDL_CreateThread(TileCache.download_loop_sdl_threadable, "Tile_Download_Thread", &tile_cache);
    var mepo = try Mepo.init(&tile_cache, cfg);
    try mepo.sdl_event_loop();
}

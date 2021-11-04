const std = @import("std");
const builtin = @import("builtin");
const Mepo = @import("./Mepo.zig");
const TileCache = @import("./TileCache.zig");
const sdl = @import("./sdlshim.zig");
const utilstrings = @import("./util/utilstrings.zig");
const utildbg = @import("./util/utildbg.zig");

pub fn main() !void {
    comptime {
        if (std.SemanticVersion.order(builtin.zig_version, try std.SemanticVersion.parse("0.8.1")) != .eq) {
            @panic("Must be built against Zig 0.8.1");
        }
    }

    const allocator = std.heap.c_allocator;
    var mode: enum { Graphical, Download } = .Graphical;
    var cfg: ?[]const u8 = null;
    
    for (try utilstrings.read_args(allocator)) |arg| {
        if (std.mem.eql(u8, arg, "-i")) {
            // -i: Read from STDIN
            utildbg.log("Reading from STDIN", .{});
            cfg = try utilstrings.read_stdin(allocator);
        } else if (std.mem.eql(u8, arg, "-d")) {
            // -d: Downloader mode (non-video), runs cfg
            mode = .Download;
        }
    }

    var tile_cache = try TileCache.init(allocator);
    var tile_download_thread = sdl.SDL_CreateThread(TileCache.download_loop_sdl_threadable, "Tile_Download_Thread", &tile_cache);
    var mepo = try Mepo.init(allocator, &tile_cache, cfg);

    utildbg.log("Boot Mepo in mode: {}", .{mode});
    switch (mode) {
        .Graphical => { 
            try mepo.sdl_event_loop(); 
        },
        .Download => { },
    }
}

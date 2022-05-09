const std = @import("std");
const config = @import("./config.zig");
const builtin = @import("builtin");
const Mepo = @import("./Mepo.zig");
const Docs = @import("./Docs.zig");
const Downloader = @import("./Downloader.zig");
const TileCache = @import("./TileCache.zig");
const sdl = @import("./sdlshim.zig");
const utildbg = @import("./util/utildbg.zig");

pub fn main() !void {
    comptime {
        const v = builtin.zig_version;
        if (v.major != 0 or v.minor != 9 or v.patch != 1)
            @panic("Must be built against Zig 0.9.1");
    }

    const allocator = std.heap.c_allocator;
    var stderr_on: bool = false;
    var mode: enum { Graphical, Download, Version, Docs } = .Graphical;
    var download_request: []const u8 = undefined;
    var use_sw_renderer = false;

    var args_it = std.process.args();
    var arg_w = args_it.next(allocator);
    while (arg_w != null) : (arg_w = args_it.next(allocator)) {
        const arg = try arg_w.?;
        if (std.mem.startsWith(u8, arg, "-doc")) {
            // -doc: Documentation mode, generates docs for mepolang
            mode = .Docs;
        } else if (std.mem.startsWith(u8, arg, "-d")) {
            // -d: Downloader mode (non-video), runs cfg
            mode = .Download;
            download_request = arg[2..];
        } else if (std.mem.startsWith(u8, arg, "-e")) {
            // -e: Enable stderr debugging
            stderr_on = true;
        } else if (std.mem.startsWith(u8, arg, "-sw")) {
            // -sw: Use software renderer instead of default HW renderer
            use_sw_renderer = true;
        } else if (std.mem.startsWith(u8, arg, "-v")) {
            // -v: Version
            mode = .Version;
        }
    }

    utildbg.log("Boot Mepo in mode: {}\n", .{mode});
    switch (mode) {
        .Docs => {
            try Docs.generate();
        },
        .Graphical => {
            Mepo.setup_signals();
            var tile_cache = try TileCache.init(allocator);
            const base_config = if (stderr_on) config.DefaultBaseConfig ++ "prefset_n debug_stderr 1" else config.DefaultBaseConfig;
            var mepo = try Mepo.init(allocator, &tile_cache, base_config, use_sw_renderer);
            mepo.init_video_and_sdl_stdin_loop() catch Mepo.graceful_terminate();
        },
        .Download => {
            var tile_cache = try TileCache.init(allocator);
            try Downloader.cache_dlbbox(&tile_cache, download_request);
        },
        .Version => {
            utildbg.log("Mepo - version {d}\n", .{0.4});
        },
    }
}

const std = @import("std");
const builtin = @import("builtin");
const Mepo = @import("./Mepo.zig");
const Downloader = @import("./Downloader.zig");
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
    var mode: enum { Graphical, Download, Version } = .Graphical;
    var download_request: []const u8 = undefined;
    var cfg: ?[]const u8 = null;

    var args_it = std.process.args();
    var arg_w = args_it.next(allocator);
    while (arg_w != null) : (arg_w = args_it.next(allocator)) {
        const arg = try arg_w.?;
        if (std.mem.eql(u8, arg, "-i")) {
            // -i: Read from STDIN
            utildbg.log("Reading from STDIN", .{});
            cfg = try read_stdin(allocator);
        } else if (std.mem.startsWith(u8, arg, "-d")) {
            // -d: Downloader mode (non-video), runs cfg
            mode = .Download;
            download_request = arg[2..];
        } else if (std.mem.startsWith(u8, arg, "-v")) {
            // -v: Version
            mode = .Version;
        }
    }

    utildbg.log("Boot Mepo in mode: {}\n", .{mode});
    switch (mode) {
        .Graphical => {
            var tile_cache = try TileCache.init(allocator);
            var mepo = try Mepo.init(allocator, &tile_cache, cfg);
            mepo.sdl_event_loop() catch Mepo.graceful_terminate();
        },
        .Download => {
            var tile_cache = try TileCache.init(allocator);
            try Downloader.cache_dlbbox(&tile_cache, download_request);
        },
        .Version => {
            utildbg.log("Mepo - version {d}\n", .{0.2});
        },
    }
}

fn read_stdin(allocator: *std.mem.Allocator) anyerror![]const u8 {
    const stream = &std.io.getStdIn().reader();
    const buffer = try allocator.alloc(u8, 1024 * 100);
    _ = try stream.read(buffer);
    return std.mem.trim(u8, buffer, " \n");
}

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
    var stderr_debugging_on: bool = false;
    var stdin_mepolang_parsing_on: bool = false;
    var mode: enum { Graphical, Download, Version, DocsMarkdown, DocsManpage, Help } = .Graphical;
    var download_request: []const u8 = undefined;
    var enable_default_config = true;
    var use_sw_renderer = false;

    var args_it = std.process.args();
    var arg_w = args_it.next(allocator);
    while (arg_w != null) : (arg_w = args_it.next(allocator)) {
        const arg = try arg_w.?;
        if (std.mem.eql(u8, arg, "-docmd")) {
            // -docmd: Documentation mode, generates markdown docs for mepolang
            mode = .DocsMarkdown;
        } else if (std.mem.eql(u8, arg, "-docman")) {
            // -docman: Documentation mode, generates manpage docs for mepolang
            mode = .DocsManpage;
        } else if (std.mem.startsWith(u8, arg, "-d")) {
            // -d: Downloader mode (non-video), runs cfg
            mode = .Download;
            download_request = arg[2..];
        } else if (std.mem.eql(u8, arg, "-i")) {
            // -i: Enable STDIN mepolang parsing
            stdin_mepolang_parsing_on = true;
        } else if (std.mem.eql(u8, arg, "-e")) {
            // -e: Enable stderr debugging
            stderr_debugging_on = true;
        } else if (std.mem.eql(u8, arg, "-sw")) {
            // -sw: Use software renderer instead of default HW renderer
            use_sw_renderer = true;
        } else if (std.mem.eql(u8, arg, "-v")) {
            // -v: Version
            mode = .Version;
        } else if (std.mem.eql(u8, arg, "-ndc")) {
            // -ndc: No default config
            enable_default_config = false;
        } else if (std.mem.eql(u8, arg, "-h")) {
            // -v: Version
            mode = .Help;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("Unknown CLI flag: '{s}'\nUsage - ", .{arg});
            mode = .Help;
        }
    }

    switch (mode) {
        .DocsMarkdown => {
            try Docs.generate(.Markdown);
        },
        .DocsManpage => {
            try Docs.generate(.Manpage);
        },
        .Graphical => {
            var tile_cache = try TileCache.init(allocator);
            const base_config = cfg: {
                const dbg = "prefset_n debug_stderr 1;";

                if (stderr_debugging_on and enable_default_config) {
                    break :cfg config.DefaultBaseConfig ++ dbg;
                } else if (stderr_debugging_on and !enable_default_config) {
                    break :cfg dbg;
                } else if (!stderr_debugging_on and enable_default_config) {
                    break :cfg config.DefaultBaseConfig;
                }
                break :cfg "";
            };
            var mepo = try Mepo.init(allocator, &tile_cache, base_config, use_sw_renderer);
            mepo.init_video_and_sdl_stdin_loop(stdin_mepolang_parsing_on) catch Mepo.graceful_terminate_sdl();
        },
        .Download => {
            var tile_cache = try TileCache.init(allocator);
            try Downloader.cache_dlbbox(&tile_cache, download_request);
        },
        .Version => {
            std.debug.print("Mepo - version {s}\n", .{config.Version});
        },
        .Help => {
            std.debug.print(
                \\Mepo {s} - fast simple hackable OSM map viewer:
                \\===============================================
                \\  mepo -docmd : Print markdown documentation for mepolang API to STDOUT
                \\  mepo -docman : Print manpage documentation for mepolang API to STDOUT
                \\  mepo -dlat_a,lon_a,lat_b,lon_b,zoom_min,zoom_max : Non-interactively download tiles for given range
                \\  mepo -i : Read mepolang from STDIN continually
                \\  mepo -e : Enable debug mode to log messages to STDERR
                \\  mepo -ndc : Disable default config, e.g. not wanting defaults bindings etc.. like `cat my_config | mepo -ndc`
                \\  mepo -sw : Use software renderer rather then default GPU/hardware based renderer
                \\  mepo -v : Print version number
                \\  mepo -h : Print this help text
                \\===============================================
                \\
                ,
                .{config.Version},
            );
        },
    }
}

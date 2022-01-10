const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");

pub fn f_preftoggle(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;

    for (&[_]struct { prop: []const u8, ptr: *bool }{
        .{ .prop = "help", .ptr = &mepo.help },
        .{ .prop = "overlay_debugbar", .ptr = &mepo.overlay_debugbar },
        .{ .prop = "overlay_pindetails", .ptr = &mepo.overlay_pindetails },
        .{ .prop = "debug_message_enabled", .ptr = &mepo.debug_message_enabled },
        .{ .prop = "debug_tiles", .ptr = &mepo.debug_tiles },
        .{ .prop = "debug_stderr", .ptr = &utildbg.debug_stderr },
        .{ .prop = "crosshair_on", .ptr = &mepo.crosshair_on },
    }) |stg| {
        if (std.mem.eql(u8, stg.prop, name)) stg.ptr.* = !stg.ptr.*;
    }

    if (std.mem.eql(u8, "tile_cache_network", name)) {
        mepo.tile_cache.set_network(!(mepo.tile_cache.thread_download != null));
    }
}

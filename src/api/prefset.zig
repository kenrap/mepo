const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");

pub fn f_prefset(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;

    // Bools
    for (&[_]struct { prop: []const u8, ptr: *bool }{
        .{ .prop = "help", .ptr = &mepo.help },
        .{ .prop = "download_bar", .ptr = &mepo.download_bar },
        .{ .prop = "debug_vars", .ptr = &mepo.debug_vars },
        .{ .prop = "debug_message_enabled", .ptr = &mepo.debug_message_enabled },
        .{ .prop = "debug_tiles", .ptr = &mepo.debug_tiles },
        .{ .prop = "debug_stderr", .ptr = &utildbg.debug_stderr },
        .{ .prop = "crosshair_on", .ptr = &mepo.crosshair_on },
    }) |stg| {
        if (std.mem.eql(u8, stg.prop, name)) stg.ptr.* = args[1].Number == 1;
    }

    // Ints
    for (&[_]struct { prop: []const u8, ptr: *u8 }{
        .{ .prop = "drag_scale", .ptr = &mepo.drag_scale },
        .{ .prop = "zoom", .ptr = &mepo.zoom },
        .{ .prop = "crosshair_size", .ptr = &mepo.crosshair_size },
    }) |stg| {
        if (std.mem.eql(u8, stg.prop, name)) stg.ptr.* = @floatToInt(u8, args[1].Number);
    }

    // Tilecache - TODO move above?
    if (std.mem.eql(u8, "tile_cache_dir", name)) {
        try mepo.tile_cache.set_cache_dir(args[1].Text);
    } else if (std.mem.eql(u8, "tile_cache_url", name)) {
        try mepo.tile_cache.set_cache_url(args[1].Text);
    } else if (std.mem.eql(u8, "tile_cache_max_n_transfers", name)) {
        mepo.tile_cache.set_max_n_transfers(@floatToInt(usize, args[1].Number));
    }
}

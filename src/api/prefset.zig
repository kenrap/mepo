const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .name = "prefset",
    // TODO: dynamic usage of mepolang 2nd arg..
    //       should there be prefset_number / prefset_text?
    .args = (&[_]types.MepoArgTag{})[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;

    // Bools
    for (&[_]struct { prop: []const u8, ptr: *bool }{
        .{ .prop = "crosshair_on", .ptr = &mepo.crosshair_on },
        .{ .prop = "debug_message_enabled", .ptr = &mepo.debug_message_enabled },
        .{ .prop = "debug_stderr", .ptr = &utildbg.debug_stderr },
        .{ .prop = "debug_tiles", .ptr = &mepo.debug_tiles },
        .{ .prop = "distance_unit_tf_km_mi", .ptr = &mepo.distance_unit_tf_km_mi },
        .{ .prop = "overlay_debugbar", .ptr = &mepo.overlay_debugbar },
        .{ .prop = "overlay_pindetails", .ptr = &mepo.overlay_pindetails },
        .{ .prop = "help", .ptr = &mepo.help },
    }) |stg| {
        if (std.mem.eql(u8, stg.prop, name)) stg.ptr.* = args[1].Number == 1;
    }

    // U8 Ints
    for (&[_]struct { prop: []const u8, ptr: *u8 }{
        .{ .prop = "fontsize_ui", .ptr = &mepo.fontsize_ui },
        .{ .prop = "drag_scale", .ptr = &mepo.drag_scale },
        .{ .prop = "zoom", .ptr = &mepo.zoom },
        .{ .prop = "crosshair_size", .ptr = &mepo.crosshair_size },
        .{ .prop = "tile_cache_max_n_transfers", .ptr = &mepo.tile_cache.max_n_transfers },
    }) |stg| {
        if (std.mem.eql(u8, stg.prop, name)) stg.ptr.* = @floatToInt(u8, args[1].Number);
    }

    // I32 Ints
    for (&[_]struct { prop: []const u8, ptr: *i32 }{
        .{ .prop = "tile_cache_expiry_seconds", .ptr = &mepo.tile_cache.expiry_seconds },
    }) |stg| {
        if (std.mem.eql(u8, stg.prop, name)) stg.ptr.* = @floatToInt(i32, args[1].Number);
    }

    // Tilecache - TODO move above?
    if (std.mem.eql(u8, "tile_cache_dir", name)) {
        try mepo.tile_cache.set_cache_dir(args[1].Text);
    } else if (std.mem.eql(u8, "tile_cache_url", name)) {
        try mepo.tile_cache.set_cache_url(args[1].Text);
    } else if (std.mem.eql(u8, "tile_cache_network", name)) {
        mepo.tile_cache.set_network(args[1].Number == 1);
    }
}

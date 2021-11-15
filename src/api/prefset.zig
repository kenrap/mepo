const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");

pub fn f_prefset(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;

    if (std.mem.eql(u8, "help", name)) {
        mepo.help = args[1].Number == 1;
    } else if (std.mem.eql(u8, "download_bar", name)) {
        mepo.download_bar = args[1].Number == 1;
    } else if (std.mem.eql(u8, "debug_vars", name)) {
        mepo.debug_vars = args[1].Number == 1;
    } else if (std.mem.eql(u8, "debug_message_enabled", name)) {
        mepo.debug_message_enabled = args[1].Number == 1;
    } else if (std.mem.eql(u8, "debug_tiles", name)) {
        mepo.debug_tiles = args[1].Number == 1;
    } else if (std.mem.eql(u8, "drag_scale", name)) {
        mepo.drag_scale = @floatToInt(i32, args[1].Number);
    } else if (std.mem.eql(u8, "debug_stderr", name)) {
        utildbg.debug_stderr = args[1].Number == 1;
    } else if (std.mem.eql(u8, "zoom", name)) {
        mepo.zoom = @floatToInt(u8, args[1].Number);
    } else if (std.mem.eql(u8, "crosshair_on", name)) {
        mepo.crosshair_on = args[1].Number == 1;
    } else if (std.mem.eql(u8, "crosshair_size", name)) {
        mepo.crosshair_size = @floatToInt(u8, args[1].Number);
    } else if (std.mem.eql(u8, "tile_cache_dir", name)) {
        try mepo.tile_cache.set_cache_dir(args[1].Text);
    } else if (std.mem.eql(u8, "tile_cache_url", name)) {
        try mepo.tile_cache.set_cache_url(args[1].Text);
    } else if (std.mem.eql(u8, "tile_cache_max_n_transfers", name)) {
        mepo.tile_cache.set_max_n_transfers(@floatToInt(usize, args[1].Number));
    }
}

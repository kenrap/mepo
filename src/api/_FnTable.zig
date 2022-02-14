const types = @import("../types.zig");
const std = @import("std");

const fn_bindings = &[_]struct { name: []const u8, func: types.MepoFn }{
    .{ .name = "bind_button", .func = @import("bind_button.zig").f_bind_button },
    .{ .name = "bind_click", .func = @import("bind_click.zig").f_bind_click },
    .{ .name = "bind_key", .func = @import("bind_key.zig").f_bind_key },
    .{ .name = "bind_signal", .func = @import("bind_signal.zig").f_bind_signal },
    .{ .name = "center_on_coords", .func = @import("center_on_coords.zig").f_center_on_coords },
    .{ .name = "center_on_mouse", .func = @import("center_on_mouse.zig").f_center_on_mouse },
    .{ .name = "center_on_pin", .func = @import("center_on_pin.zig").f_center_on_pin },
    .{ .name = "cache_dlbbox", .func = @import("cache_dlbbox.zig").f_cache_dlbbox },
    .{ .name = "cache_queueclear", .func = @import("cache_queueclear.zig").f_cache_queueclear },
    .{ .name = "cache_dlradius", .func = @import("cache_dlradius.zig").f_cache_dlradius },
    .{ .name = "fileload", .func = @import("fileload.zig").f_fileload },
    .{ .name = "move_relative", .func = @import("move_relative.zig").f_move_relative },
    .{ .name = "pin_add", .func = @import("pin_add.zig").f_pin_add },
    .{ .name = "pin_cycle", .func = @import("pin_cycle.zig").f_pin_cycle },
    .{ .name = "pin_deactivate", .func = @import("pin_deactivate.zig").f_pin_deactivate },
    .{ .name = "pin_groupprefset", .func = @import("pin_groupprefset.zig").f_pin_groupprefset },
    .{ .name = "pin_meta", .func = @import("pin_meta.zig").f_pin_meta },
    .{ .name = "pin_delete", .func = @import("pin_delete.zig").f_pin_delete },
    .{ .name = "pin_purge", .func = @import("pin_purge.zig").f_pin_purge },
    .{ .name = "prefset", .func = @import("prefset.zig").f_prefset },
    .{ .name = "preftoggle", .func = @import("preftoggle.zig").f_preftoggle },
    .{ .name = "quit", .func = @import("quit.zig").f_quit },
    .{ .name = "shellpipe", .func = @import("shellpipe.zig").f_shellpipe },
    .{ .name = "zoom_relative", .func = @import("zoom_relative.zig").f_zoom_relative },
};

pub fn get(get_fn: []const u8) ?types.MepoFn {
    for (fn_bindings) |f| {
        if (std.mem.eql(u8, f.name, get_fn)) return f.func;
    }
    return null;
}

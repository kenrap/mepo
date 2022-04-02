const types = @import("../types.zig");
const std = @import("std");

const fn_specs = &[_]types.MepoFnSpec{
    @import("bind_button.zig").spec,
    @import("bind_click.zig").spec,
    @import("bind_gesture.zig").spec,
    @import("bind_key.zig").spec,
    @import("bind_signal.zig").spec,
    @import("cache_dlbbox.zig").spec,
    @import("cache_dlradius.zig").spec,
    @import("cache_queueclear.zig").spec,
    @import("center_on_coords.zig").spec,
    @import("center_on_mouse.zig").spec,
    @import("center_on_pin.zig").spec,
    @import("clipcopy.zig").spec,
    @import("fileload.zig").spec,
    @import("move_relative.zig").spec,
    @import("pin_add.zig").spec,
    @import("pin_cycle.zig").spec,
    @import("pin_deactivate.zig").spec,
    @import("pin_delete.zig").spec,
    @import("pin_groupprefset.zig").spec,
    @import("pin_meta.zig").spec,
    @import("pin_purge.zig").spec,
    @import("prefinc.zig").spec,
    @import("prefset.zig").spec,
    @import("preftoggle.zig").spec,
    @import("quit.zig").spec,
    @import("shellpipe.zig").spec,
    @import("zoom_relative.zig").spec,
};

pub fn get(get_fn: []const u8) ?types.MepoFnSpec {
    for (fn_specs) |f| {
        if (std.mem.eql(u8, f.name, get_fn)) return f;
    }
    return null;
}

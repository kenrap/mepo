const types = @import("../types.zig");
const std = @import("std");

const fn_bindings = &[_]struct { name: []const u8, spec: types.MepoFnSpec }{
    .{ .name = "bind_button", .spec = @import("bind_button.zig").spec },
    .{ .name = "bind_click", .spec = @import("bind_click.zig").spec },
    .{ .name = "bind_key", .spec = @import("bind_key.zig").spec },
    .{ .name = "bind_gesture", .spec = @import("bind_gesture.zig").spec },
    .{ .name = "bind_signal", .spec = @import("bind_signal.zig").spec },
    .{ .name = "center_on_coords", .spec = @import("center_on_coords.zig").spec },
    .{ .name = "center_on_mouse", .spec = @import("center_on_mouse.zig").spec },
    .{ .name = "center_on_pin", .spec = @import("center_on_pin.zig").spec },
    .{ .name = "cache_dlbbox", .spec = @import("cache_dlbbox.zig").spec },
    .{ .name = "cache_queueclear", .spec = @import("cache_queueclear.zig").spec },
    .{ .name = "cache_dlradius", .spec = @import("cache_dlradius.zig").spec },
    .{ .name = "fileload", .spec = @import("fileload.zig").spec },
    .{ .name = "move_relative", .spec = @import("move_relative.zig").spec },
    .{ .name = "pin_add", .spec = @import("pin_add.zig").spec },
    .{ .name = "pin_cycle", .spec = @import("pin_cycle.zig").spec },
    .{ .name = "pin_deactivate", .spec = @import("pin_deactivate.zig").spec },
    .{ .name = "pin_groupprefset", .spec = @import("pin_groupprefset.zig").spec },
    .{ .name = "pin_meta", .spec = @import("pin_meta.zig").spec },
    .{ .name = "pin_delete", .spec = @import("pin_delete.zig").spec },
    .{ .name = "pin_purge", .spec = @import("pin_purge.zig").spec },
    .{ .name = "prefinc", .spec = @import("prefinc.zig").spec },
    .{ .name = "prefset", .spec = @import("prefset.zig").spec },
    .{ .name = "preftoggle", .spec = @import("preftoggle.zig").spec },
    .{ .name = "quit", .spec = @import("quit.zig").spec },
    .{ .name = "shellpipe", .spec = @import("shellpipe.zig").spec },
    .{ .name = "zoom_relative", .spec = @import("zoom_relative.zig").spec },
};

pub fn get(get_fn: []const u8) ?types.MepoFnSpec {
    for (fn_bindings) |f| {
        if (std.mem.eql(u8, f.name, get_fn)) return f.spec;
    }
    return null;
}

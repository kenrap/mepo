const types = @import("../types.zig");
const std = @import("std");

pub fn generate_fn_table() anyerror!types.MepoFnTable {
    var ft = types.MepoFnTable.init(std.heap.c_allocator);

    const fn_bindings = &[_]struct { name: []const u8, func: types.MepoFn }{
        .{ .name = "move_relative", .func = @import("move_relative.zig").f_move_relative },
        .{ .name = "bind_key", .func = @import("bind_key.zig").f_bind_key },
        .{ .name = "center_on_coords", .func = @import("center_on_coords.zig").f_center_on_coords },
        .{ .name = "zoom_relative", .func = @import("zoom_relative.zig").f_zoom_relative },
        .{ .name = "prefset", .func = @import("prefset.zig").f_prefset },
        .{ .name = "shellpipe", .func = @import("shellpipe.zig").f_shellpipe },
        .{ .name = "pin_add", .func = @import("pin_add.zig").f_pin_add },
        .{ .name = "pin_cycle", .func = @import("pin_cycle.zig").f_pin_cycle },
        .{ .name = "pin_deactivate", .func = @import("pin_deactivate.zig").f_pin_deactivate },
        .{ .name = "pin_purge", .func = @import("pin_purge.zig").f_pin_purge },
        .{ .name = "center_on_mouse", .func = @import("center_on_mouse.zig").f_center_on_mouse },
        .{ .name = "download_bbox", .func = @import("download_bbox.zig").f_download_bbox },
    };

    try ft.ensureCapacity(fn_bindings.len);
    for (fn_bindings) |f| {
        try ft.put(f.name, f.func);
    }

    return ft;
}

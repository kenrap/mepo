const types = @import("../types.zig");
const std = @import("std");

pub fn generate_fn_table() anyerror!types.MepoFnTable {
    var ft = types.MepoFnTable.init(std.heap.c_allocator);
    try ft.ensureCapacity(1000);
    try ft.put("move_relative", @import("move_relative.zig").f_move_relative);
    try ft.put("bind_key", @import("bind_key.zig").f_bind_key);
    try ft.put("center_on_coords", @import("center_on_coords.zig").f_center_on_coords);
    try ft.put("zoom_relative", @import("zoom_relative.zig").f_zoom_relative);
    try ft.put("prefset", @import("prefset.zig").f_prefset);
    try ft.put("shellpipe", @import("shellpipe.zig").f_shellpipe);
    try ft.put("pin_add", @import("pin_add.zig").f_pin_add);
    try ft.put("pin_cycle", @import("pin_cycle.zig").f_pin_cycle);
    try ft.put("pin_deactivate", @import("pin_deactivate.zig").f_pin_deactivate);
    try ft.put("center_on_mouse", @import("center_on_mouse.zig").f_center_on_mouse);
    return ft;
}

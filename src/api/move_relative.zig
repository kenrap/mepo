const Fmap = @import("../Fmap.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_move_relative(fmap: *Fmap, args: [5]types.MepoArg) !void {
    const rel_x = @floatToInt(i32, args[0].Number);
    const rel_y = @floatToInt(i32, args[1].Number);
    move_relative(fmap, rel_x, rel_y);
}

pub fn move_relative(fmap: *Fmap, relative_x: i32, relative_y: i32) void {
    fmap.x += relative_x;
    fmap.y += relative_y;
}

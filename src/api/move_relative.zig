const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_move_relative(mepo: *Mepo, args: [5]types.MepoArg) !void {
    const rel_x = @floatToInt(i32, args[0].Number);
    const rel_y = @floatToInt(i32, args[1].Number);
    move_relative(mepo, rel_x, rel_y);
}

pub fn move_relative(mepo: *Mepo, relative_x: i32, relative_y: i32) void {
    mepo.x += relative_x;
    mepo.y += relative_y;
}

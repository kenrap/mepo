const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_move_relative(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const rel_x = @floatToInt(i32, args[0].Number);
    const rel_y = @floatToInt(i32, args[1].Number);
    move_relative(mepo, rel_x, rel_y);
}

pub fn move_relative(mepo: *Mepo, relative_x: i32, relative_y: i32) void {
    mepo.set_x(mepo.get_x() + relative_x);
    mepo.set_y(mepo.get_y() + relative_y);
}

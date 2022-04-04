const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "move_relative",
    .args = (&[_]types.MepoFnSpecArg{
        .{.tag = .Number, .name = "rel_x"},
        .{.tag = .Number, .name = "rel_y"},
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const rel_x = @floatToInt(i32, args[0].Number);
    const rel_y = @floatToInt(i32, args[1].Number);
    mepo.set_x(mepo.get_x() + rel_x);
    mepo.set_y(mepo.get_y() + rel_y);
}

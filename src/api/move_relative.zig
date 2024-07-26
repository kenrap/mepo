const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "move_relative",
    .desc = "Move the map by a relative x/y amount.",
    .args = &.{
        .{ .tag = .Number, .name = "rel_x", .desc = "Relative x amount", .default_value = .{ .Number = 0 } },
        .{ .tag = .Number, .name = "rel_y", .desc = "Relative y amount", .default_value = .{ .Number = 0 } },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const rel_x: i32 = @intFromFloat(args[0].Number);
    const rel_y: i32 = @intFromFloat(args[1].Number);
    mepo.set_x(mepo.get_x() + rel_x);
    mepo.set_y(mepo.get_y() + rel_y);
}

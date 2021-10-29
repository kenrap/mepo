const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_zoom_relative(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const relative = @floatToInt(i32, args[0].Number);
    zoom_relative(mepo, relative);
}

pub fn zoom_relative(mepo: *Mepo, relative: i32) void {
    mepo.zoom = @intCast(u8, std.math.min(19, std.math.max(0, @intCast(i32, mepo.zoom) + relative)));
}

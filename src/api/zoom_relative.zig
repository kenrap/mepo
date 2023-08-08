const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const p = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "zoom_relative",
    .desc = "Update the map's zoom level by a relative delta.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "zoom_delta", .desc = "Zoom level relative delta" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    zoom_relative(mepo, @intFromFloat(args[0].Number));
}

pub fn zoom_relative(_: *Mepo, relative: i32) void {
    p.set_n(p.pref.zoom, @floatFromInt(@min(19, @max(0, p.get(p.pref.zoom).u)) + relative));
}

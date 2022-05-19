const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilprefs = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "zoom_relative",
    .desc = "Update the map's zoom level by a relative delta",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "zoom_delta", .desc = "Zoom level relative delta" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const relative = @floatToInt(i32, args[0].Number);
    zoom_relative(mepo, relative);
}

pub fn zoom_relative(_: *Mepo, relative: i32) void {
    utilprefs.set_n("zoom", @intToFloat(f64, @intCast(u8, std.math.min(19, std.math.max(0, @intCast(i32, utilprefs.get("zoom").u) + relative)))));
}

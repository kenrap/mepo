const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "center_on_coords",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "lat" },
        .{ .tag = .Number, .name = "lon" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const lat = args[0].Number;
    const lon = args[1].Number;
    mepo.lon = lon;
    mepo.lat = lat;
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const p = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "center_on_coords",
    .desc = "Center the map on the given coordinate",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "lat", .desc = "Latitude" },
        .{ .tag = .Number, .name = "lon", .desc = "Longitude" },
    })[0..],
    .execute = execute,
};

fn execute(_: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const lat = args[0].Number;
    const lon = args[1].Number;
    p.set_n(p.pref.lat, lat);
    p.set_n(p.pref.lon, lon);
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilarg = @import("../util/utilarg.zig");

pub const spec = .{
    .args = (&[_]types.MepoArgTag{ .Number, .Number })[0..],
};

pub fn f_center_on_coords(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    _ = utilarg.validate_args(spec, args) catch |e| return e;
    const lat = args[0].Number;
    const lon = args[1].Number;
    center_on_coords(mepo, lat, lon);
}

fn center_on_coords(mepo: *Mepo, lat: f64, lon: f64) void {
    mepo.lon = lon;
    mepo.lat = lat;
}

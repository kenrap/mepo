const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");

pub fn f_center_on_coords(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const lat = args[0].Number;
    const lon = args[1].Number;
    center_on_coords(mepo, lat, lon);
}

pub fn center_on_coords(mepo: *Mepo, lat: f64, lon: f64) void {
    mepo.x = conversionutil.lon_to_px_x(lon, mepo.zoom);
    mepo.y = conversionutil.lat_to_px_y(lat, mepo.zoom);
}

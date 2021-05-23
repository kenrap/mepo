const Fmap = @import("../Fmap.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");

pub fn f_center_on_coords(fmap: *Fmap, args: [5]types.MepoArg) !void {
    const lat = args[0].Number;
    const lon = args[1].Number;
    center_on_coords(fmap, lat, lon);
}

pub fn center_on_coords(fmap: *Fmap, lat: f64, lon: f64) void {
    fmap.x = conversionutil.lon_to_px(lon, fmap.zoom);
    fmap.y = conversionutil.lat_to_px(lat, fmap.zoom);
}

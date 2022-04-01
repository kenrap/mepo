const Mepo = @import("../Mepo.zig");
const TileCache = @import("../TileCache.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utildbg = @import("../util/utildbg.zig");
const config = @import("../config.zig");

pub const spec = .{
    .args = (&[_]types.MepoArgTag{ .Number, .Number, .Number, .Number, .Number, .Number })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const a_lat = args[0].Number;
    const a_lon = args[1].Number;
    const b_lat = args[2].Number;
    const b_lon = args[3].Number;
    const zoom_min = @floatToInt(i32, args[4].Number);
    const zoom_max = @floatToInt(i32, args[5].Number);

    try cache_dlbbox(mepo, a_lat, a_lon, b_lat, b_lon, zoom_min, zoom_max);
}

fn cache_dlbbox(mepo: *Mepo, a_lat: f64, a_lon: f64, b_lat: f64, b_lon: f64, zoom_min: i32, zoom_max: i32) !void {
    mepo.tile_cache.set_queue(TileCache.DownloadBBoxRequest{
        .a_lat = a_lat,
        .a_lon = a_lon,
        .b_lat = b_lat,
        .b_lon = b_lon,
        .zoom_min = zoom_min,
        .zoom_max = zoom_max,
    });
}

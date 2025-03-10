const Mepo = @import("../Mepo.zig");
const TileCache = @import("../TileCache.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utildbg = @import("../util/utildbg.zig");
const config = @import("../config.zig");

pub const spec = types.MepoFnSpec{
    .name = "cache_dlradius",
    .desc = "Queue tiles for a bounding box to download to the cache in the background for the given zoom levels. Writes directly to filesystem cache (path determined by `tile_cache_dir` preference) as tiles are downloaded.",
    .args = &.{
        .{ .tag = .Number, .name = "lat", .desc = "Centerpoint latitude" },
        .{ .tag = .Number, .name = "lon", .desc = "Centerpoint longitude" },
        .{ .tag = .Number, .name = "zoom_min", .desc = "Minimum zoom level" },
        .{ .tag = .Number, .name = "zoom_max", .desc = "Maximum zoom level" },
        .{ .tag = .Number, .name = "km_radius", .desc = "Radius from centerpoint in kilometers to download tiles for" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try cache_dlradius(mepo, args[0].Number, args[1].Number, @intFromFloat(args[2].Number), @intFromFloat(args[3].Number), args[4].Number);
}

fn cache_dlradius(mepo: *Mepo, center_lat: f64, center_lon: f64, zoom_min: i32, zoom_max: i32, km_radius: f64) !void {
    var start_lat = center_lat;
    var end_lat = center_lat;
    var start_lon = center_lon;
    var end_lon = center_lon;

    while (km_radius > utilconversion.distance_haversine(.Km, start_lat, center_lon, center_lat, center_lon))
        start_lat -= 1;
    while (km_radius > utilconversion.distance_haversine(.Km, end_lat, center_lon, center_lat, center_lon))
        end_lat += 1;
    while (km_radius > utilconversion.distance_haversine(.Km, center_lat, start_lon, center_lat, center_lon))
        start_lon -= 1;
    while (km_radius > utilconversion.distance_haversine(.Km, center_lat, end_lon, center_lat, center_lon))
        end_lon += 1;

    std.debug.print("Queueing {} {} to {} {} from {} {} based on {} {}\n", .{ start_lat, end_lat, start_lon, end_lon, zoom_min, zoom_max, center_lat, center_lon });

    mepo.tile_cache.set_queue(TileCache.DownloadBBoxRequest{
        .a_lat = start_lat,
        .a_lon = start_lon,
        .b_lat = end_lat,
        .b_lon = end_lon,
        .zoom_min = zoom_min,
        .zoom_max = zoom_max,
    });
}

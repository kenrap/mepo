const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utildbg = @import("../util/utildbg.zig");
const config = @import("../config.zig");

pub fn f_cache_radiusdl(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const lat = args[0].Number;
    const lon = args[1].Number;
    const zoom_min = @floatToInt(i32, args[2].Number);
    const zoom_max = @floatToInt(i32, args[3].Number);
    const km_radius = args[4].Number;

    try cache_radiusdl(mepo, lat, lon, zoom_min, zoom_max, km_radius);
}

fn cache_radiusdl(mepo: *Mepo, center_lat: f64, center_lon: f64, zoom_min: i32, zoom_max: i32, km_radius: f64) !void {
    const step_km = 1;
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

    std.debug.warn("Queueing {} {} to {} {} from {} {} based on {} {}\n", .{ start_lat, end_lat, start_lon, end_lon, zoom_min, zoom_max, center_lat, center_lon });

    _ = try mepo.tile_cache.tile_queue_no_surface_load_bbox_threadlaunch(.{
        .a_lat = start_lat,
        .a_lon = start_lon,
        .b_lat = end_lat,
        .b_lon = end_lon,
        .zoom_min = zoom_min,
        .zoom_max = zoom_max,
    });
}

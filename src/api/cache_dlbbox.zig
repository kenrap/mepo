const Mepo = @import("../Mepo.zig");
const TileCache = @import("../TileCache.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utildbg = @import("../util/utildbg.zig");
const config = @import("../config.zig");

pub const spec = .{
    .name = "cache_dlbbox",
    .desc = "Queue tiles for a bounding box to download to the cache in the background for the given zoom levels. Writes directly to filesystem cache (path determined by `tile_cache_dir` preference) as tiles are downloaded.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "a_lat", .desc = "Starting latitude" },
        .{ .tag = .Number, .name = "a_lon", .desc = "Starting longitude" },
        .{ .tag = .Number, .name = "b_lat", .desc = "Ending latitude" },
        .{ .tag = .Number, .name = "b_lon", .desc = "Ending longitude" },
        .{ .tag = .Number, .name = "zoom_min", .desc = "Minimum zoom level" },
        .{ .tag = .Number, .name = "zoom_max", .desc = "Maximum zoom level" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try cache_dlbbox(mepo,
        args[0].Number, args[1].Number, args[2].Number, args[3].Number,
        @intFromFloat(args[4].Number), @intFromFloat(args[5].Number));
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

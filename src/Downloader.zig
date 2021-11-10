const std = @import("std");
const utilconversion = @import("util/utilconversion.zig");
const TileCache = @import("./TileCache.zig");

const DownloadRequest = struct {
    a_lat: f64,
    a_lon: f64,
    b_lat: f64,
    b_lon: f64,
    zoom_min: i32,
    zoom_max: i32,
};

pub fn download_bbox(tile_cache: *TileCache, download_request_str: []const u8) !void {
    std.debug.warn("Downloading based on BBox request: {s}\n", .{download_request_str});

    const delay_seconds = 3;
    const average_tile_size_bytes = 1024 * 20;
    const dl_req = try parse_download_request(download_request_str);
    const stats = try tile_cache.tile_queue_no_surface_load_bbox(
        dl_req.a_lat,
        dl_req.a_lon,
        dl_req.b_lat,
        dl_req.b_lon,
        dl_req.zoom_min,
        dl_req.zoom_max,
    );
    const dist_w = utilconversion.distance_km_haversine(
        dl_req.a_lat,
        dl_req.a_lon,
        dl_req.a_lat,
        dl_req.b_lon,
    );
    const dist_h = utilconversion.distance_km_haversine(
        dl_req.a_lat,
        dl_req.a_lon,
        dl_req.b_lat,
        dl_req.a_lon,
    );

    std.debug.warn(
        \\Bbox Distance: {d:.3}km squared ({d:.3}m x {d:.3}m)
        \\Bbox Tiles queued ({} tiles): {} tiles queued; {} tiles already cached
        \\Estimate download: {d:.5} megabytes
        \\
        \\Begining download in {d}s
        \\
    ,
        .{
            dist_w * dist_h,
            dist_w,
            dist_h,
            stats.n_queued + stats.n_cached,
            stats.n_queued,
            stats.n_cached,
            @divFloor(average_tile_size_bytes * stats.n_queued, (1024 * 1024)),
            delay_seconds,
        },
    );
    std.time.sleep(std.time.ns_per_s * delay_seconds);

    try tile_cache.set_cache_dir("~/.cache/mepo/tiles");
    try tile_cache.set_cache_url("https://tile.openstreetmap.org/%3$d/%1$d/%2$d.png");
    const result = tile_cache.download_loop(false);
}

fn parse_download_request(download_request_str: []const u8) !DownloadRequest {
    var a_lat: f64 = undefined;
    var a_lon: f64 = undefined;
    var b_lat: f64 = undefined;
    var b_lon: f64 = undefined;
    var zoom_min: i32 = undefined;
    var zoom_max: i32 = undefined;

    var tokens_it = std.mem.tokenize(download_request_str, ",");
    var i: usize = 0;
    while (tokens_it.next()) |token| {
        switch (i) {
            0 => a_lat = try std.fmt.parseFloat(f64, token),
            1 => a_lon = try std.fmt.parseFloat(f64, token),
            2 => b_lat = try std.fmt.parseFloat(f64, token),
            3 => b_lon = try std.fmt.parseFloat(f64, token),
            4 => zoom_min = try std.fmt.parseInt(i32, token, 10),
            5 => zoom_max = try std.fmt.parseInt(i32, token, 10),
            else => return error.DownloadBboxTooManyArguments,
        }
        i += 1;
    }
    if (i < 6) return error.DownloadBboxTooFewArguments;

    return DownloadRequest{
        .a_lat = a_lat,
        .a_lon = a_lon,
        .b_lat = b_lat,
        .b_lon = b_lon,
        .zoom_min = zoom_min,
        .zoom_max = zoom_max,
    };
}

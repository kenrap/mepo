const std = @import("std");
const utilconversion = @import("util/utilconversion.zig");
const TileCache = @import("./TileCache.zig");

pub fn cache_dlbbox(tile_cache: *TileCache, download_request_str: []const u8) !void {
    std.debug.print("Downloading based on BBox request: {s}\n", .{download_request_str});

    try tile_cache.set_cache_dir("$XDG_CACHE_HOME/mepo/tiles");
    try tile_cache.set_cache_url("https://tile.openstreetmap.org/%3$d/%1$d/%2$d.png");

    const delay_seconds = 3;
    const average_tile_size_bytes = 1024 * 20;
    const dl_req = try parse_download_request(download_request_str);
    const stats = try tile_cache.tile_bg_bbox_queue(dl_req, false);
    const dist_w = utilconversion.distance_haversine(
        .Km,
        dl_req.a_lat,
        dl_req.a_lon,
        dl_req.a_lat,
        dl_req.b_lon,
    );
    const dist_h = utilconversion.distance_haversine(
        .Km,
        dl_req.a_lat,
        dl_req.a_lon,
        dl_req.b_lat,
        dl_req.a_lon,
    );

    std.debug.print(
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
    _ = tile_cache.download_loop(false) catch unreachable;
}

fn parse_download_request(download_request_str: []const u8) !TileCache.DownloadBBoxRequest {
    var a_lat: f64 = undefined;
    var a_lon: f64 = undefined;
    var b_lat: f64 = undefined;
    var b_lon: f64 = undefined;
    var zoom_min: i32 = undefined;
    var zoom_max: i32 = undefined;

    var tokens_it = std.mem.tokenizeSequence(u8, download_request_str, ",");
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

    return TileCache.DownloadBBoxRequest{
        .a_lat = a_lat,
        .a_lon = a_lon,
        .b_lat = b_lat,
        .b_lon = b_lon,
        .zoom_min = zoom_min,
        .zoom_max = zoom_max,
    };
}

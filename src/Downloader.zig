const std = @import("std");
const TileCache = @import("./TileCache.zig");

pub fn download_bbox(tile_cache :*TileCache, download_request: []const u8) !void {
    std.debug.warn("Downloading based on BBox request: {s}", .{download_request});
    var a_lat : f64 = undefined;
    var a_lon : f64 = undefined;
    var b_lat : f64 = undefined;
    var b_lon : f64 = undefined;
    var zoom_min : i32 = undefined;
    var zoom_max : i32 = undefined;

    var tokens_it = std.mem.tokenize(download_request, ",");
    var i : usize = 0;
    while (tokens_it.next()) |token| {
        switch (i) {
            0 => { a_lat = try std.fmt.parseFloat(f64, token); },
            1 => { a_lon = try std.fmt.parseFloat(f64, token); },
            2 => { b_lat = try std.fmt.parseFloat(f64, token); },
            3 => { b_lon = try std.fmt.parseFloat(f64, token); },
            4 => { zoom_min = try std.fmt.parseInt(i32, token, 10); },
            5 => { zoom_max = try std.fmt.parseInt(i32, token, 10); },
            else => { return error.DownloadBboxTooManyArguments; }
        }
        i += 1;
    }
    if (i < 6) return error.DownloadBboxTooFewArguments;

    try tile_cache.set_cache_dir("~/.cache/mepo/tiles");
    try tile_cache.set_cache_url("https://tile.openstreetmap.org/%3$d/%1$d/%2$d.png");

    const stats = try tile_cache.tile_queue_no_surface_load_bbox(a_lat, a_lon, b_lat, b_lon, zoom_min, zoom_max);
    const average_tile_size_bytes = 1024 * 20;
    std.debug.warn(
      \\Bbox queued ({} tiles): {} tiles queued; {} tiles already cached
      \\Estimate download: {} megabytes
      \\
      , 
      .{
        stats.n_queued + stats.n_cached,
        stats.n_queued,
        stats.n_cached,
        @divFloor(average_tile_size_bytes * stats.n_queued, (1024 * 1024))
      },
    );

    std.debug.warn("Begining downloads in 3s\n", .{});
    std.time.sleep(std.time.ns_per_s * 3);
    const result = tile_cache.download_loop(false);
}

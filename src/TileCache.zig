const std = @import("std");
const curl = @cImport({
    @cInclude("curl/curl.h");
});
const cstdio = @cImport({
    @cInclude("stdio.h");
});
const sdl = @import("./sdlshim.zig");
const types = @import("./types.zig");
const config = @import("./config.zig");
const utilsdl = @import("./util/utilsdl.zig");
const utilconversion = @import("./util/utilconversion.zig");
const utilfile = @import("./util/utilfile.zig");
const utildbg = @import("./util/utildbg.zig");
const datastructure = @import("./datastructure/datastructure.zig");

pub const TransferDatum = struct {
    client: *curl.CURL,
    coords: types.XYZ,
    data_arraylist: std.ArrayList(u8),
    progress_dl_now: ?c_long,
    progress_dl_total: ?c_long,
    load_to_texture: bool,
};
const TileDataTag = enum {
    transfer_datum,
    texture,
    queued_position,
    error_type,
};
pub const TileData = union(TileDataTag) {
    transfer_datum: TransferDatum,
    texture: *sdl.SDL_Texture,
    queued_position: u32,
    error_type: enum { Offline },
};

allocator: *std.mem.Allocator,
download_thread: ?*sdl.SDL_Thread,
byte_counter: u64 = 0,
cache_dir: ?std.fs.Dir,
curl_multi: *curl.CURLM,
max_n_transfers: usize = 20,
mutex: std.Thread.Mutex,
queue_lifo: datastructure.Lifo(types.XYZ, bool),
renderer: ?*sdl.SDL_Renderer,
source_url: ?[:0]const u8,
texture_map: std.array_hash_map.AutoArrayHashMap(types.XYZ, *sdl.SDL_Texture),
transfer_map: std.array_hash_map.AutoArrayHashMap(types.XYZ, *TransferDatum),

/// Retreives a tile from cache
/// If tile is not present & will queue tile to be downloaded if downloading
/// thread is present
pub fn tile_retrieve(tile_cache: *@This(), coords: types.XYZ) !TileData {
    const lock = tile_cache.mutex.acquire();
    defer lock.release();

    var file_cached_png_opt: ?[]u8 = null;

    if (tile_cache.texture_map.get(coords)) |tile| {
        return TileData{ .texture = tile };
    } else if (tile_cache.transfer_map.get(coords)) |transfer| {
        return TileData{ .transfer_datum = transfer.* };
    } else if (tile_cache.cache_dir) |cache_dir| load_from_fs: {
        const png = try png_path(tile_cache.allocator, tile_cache.source_url.?, coords);
        defer tile_cache.allocator.free(png);
        file_cached_png_opt = cache_dir.readFileAlloc(tile_cache.allocator, png, 500000) catch null;
        if (file_cached_png_opt) |file_cached_png| {
            defer tile_cache.allocator.free(file_cached_png);
            const text = tile_cache.load_data_to_texture(coords, file_cached_png) catch {
                break :load_from_fs;
            };
            return TileData{ .texture = text };
        }
    }

    if (tile_cache.download_thread == null) {
        return TileData{ .error_type = .Offline };
    } else {
        try tile_cache.queue_lifo.put(coords, true);
        return TileData{
            .queued_position = @intCast(u32, if (tile_cache.queue_lifo.getIndex(coords)) |index| index else 0),
        };
    }
}

/// Queues tile without loading to surface/memory
/// Will queue tiles indiscriminate of whether downloading thread is
/// present.
fn tile_queue_no_surface_load(tile_cache: *@This(), coords: types.XYZ) !bool {
    const lock = tile_cache.mutex.acquire();
    defer lock.release();

    if (tile_cache.cache_dir) |cache_dir| check_exists: {
        const png = try png_path(tile_cache.allocator, tile_cache.source_url.?, coords);
        defer tile_cache.allocator.free(png);
        cache_dir.access(png, .{}) catch break :check_exists;
        return false;
    }

    try tile_cache.queue_lifo.put(coords, false);
    return true;
}

const QueuedInfo = struct { n_queued: usize, n_cached: usize };

pub fn tile_queue_no_surface_load_bbox(tile_cache: *@This(), a_lat: f64, a_lon: f64, b_lat: f64, b_lon: f64, zoom_min: i32, zoom_max: i32) !QueuedInfo {
    const lat_min = if (a_lat < b_lat) a_lat else b_lat;
    const lat_max = if (a_lat > b_lat) a_lat else b_lat;
    const lon_min = if (a_lon < b_lon) a_lon else b_lon;
    const lon_max = if (a_lon > b_lon) a_lon else b_lon;

    if (zoom_min > zoom_max or
        zoom_max < 0 or
        zoom_max > 19 or
        zoom_min < 0 or
        zoom_min > 19) return error.InvalidZoomRange;

    var n_cached: usize = 0;
    var n_queued: usize = 0;

    var z: u32 = @intCast(u32, zoom_min);
    while (z <= zoom_max) : (z += 1) {
        const x_min = @divFloor(utilconversion.lon_to_px_x(lon_min, z), config.Tsize);
        const x_max = @divFloor(utilconversion.lon_to_px_x(lon_max, z), config.Tsize);
        const y_min = @divFloor(utilconversion.lat_to_px_y(lat_max, z), config.Tsize);
        const y_max = @divFloor(utilconversion.lat_to_px_y(lat_min, z), config.Tsize);
        var x: i32 = x_min;
        while (x <= x_max) : (x += 1) {
            var y: i32 = y_min;
            while (y <= y_max) : (y += 1) {
                utildbg.log("Tile cache queueing x={d} y={d} z={d}\n", .{ x, y, z });
                if (try tile_cache.tile_queue_no_surface_load(.{ .x = @intCast(u32, x), .y = @intCast(u32, y), .z = @intCast(u8, z) })) {
                    n_queued += 1;
                } else {
                    n_cached += 1;
                }
            }
        }
    }

    return QueuedInfo{
        .n_cached = n_cached,
        .n_queued = n_queued,
    };
}

fn add_to_curl_multi(tile_cache: *@This(), coords: types.XYZ, load_to_texture: bool) !void {
    if (tile_cache.transfer_map.get(coords)) |_| return;

    var transfer_datum: *TransferDatum = datum: {
        var dat = try tile_cache.allocator.create(TransferDatum);
        dat.client = curl.curl_easy_init().?;
        dat.coords = coords;
        dat.data_arraylist = std.ArrayList(u8).init(tile_cache.allocator);
        dat.progress_dl_now = null;
        dat.progress_dl_total = null;
        dat.load_to_texture = load_to_texture;
        break :datum dat;
    };
    try tile_cache.transfer_map.put(coords, transfer_datum);

    var tile_url = url: {
        var url = try tile_cache.allocator.alloc(u8, tile_cache.source_url.?.len + (3 * 10));
        if (cstdio.sprintf(
            &url[0],
            tile_cache.source_url.?,
            @intCast(c_int, coords.x),
            @intCast(c_int, coords.y),
            @intCast(c_int, coords.z),
        ) < 0) return error.TileURLSprintfFail;
        break :url url;
    };
    defer tile_cache.allocator.free(tile_url);

    try curl_setopt(transfer_datum.client, curl.CURLOPT_NOPROGRESS, @intCast(c_long, 1));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_NOSIGNAL, @intCast(c_long, 1));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_CONNECTTIMEOUT, @intCast(c_long, config.DownloadTimeoutSeconds));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_TIMEOUT, @intCast(c_long, config.DownloadTimeoutSeconds));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_URL, @ptrCast(*c_void, tile_url));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_USERAGENT, config.DownloadUseragent);
    try curl_setopt(transfer_datum.client, curl.CURLOPT_VERBOSE, @intCast(c_long, 0));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_WRITEDATA, transfer_datum);
    try curl_setopt(transfer_datum.client, curl.CURLOPT_WRITEFUNCTION, tile_write_curl_callback);
    try curl_setopt(transfer_datum.client, curl.CURLOPT_XFERINFODATA, transfer_datum);
    try curl_setopt(transfer_datum.client, curl.CURLOPT_XFERINFOFUNCTION, tile_xferinfo_curl_callback);

    try curl_errorcheck(curl.curl_multi_add_handle(tile_cache.curl_multi, transfer_datum.client));
    utildbg.log("Add multi handle {any}\n", .{coords});
}

fn curl_errorcheck(response: curl.CURLMcode) !void {
    if (response == @intToEnum(curl.CURLMcode, curl.CURLM_OK)) {
        return;
    }
    return error.CurlMultiFail;
}

fn curl_setopt(client: *curl.CURL, opt: c_int, value: anytype) !void {
    if (@intToEnum(curl.CURLcode, curl.CURLE_OK) != curl.curl_easy_setopt(client, @intToEnum(curl.CURLoption, opt), value)) {
        return error.CurlEasySetOptFail;
    }
}

fn curl_client_to_coords(tile_cache: *@This(), client: ?*curl.CURL) ?types.XYZ {
    var it = tile_cache.transfer_map.iterator();
    while (it.next()) |kv| {
        if (kv.value_ptr.*.client == client) {
            return kv.value_ptr.*.coords;
        }
    }
    return null;
}

fn load_data_to_texture(tile_cache: *@This(), coords: types.XYZ, data: []u8) !*sdl.SDL_Texture {
    if (data.len == 0) return error.LoadToSurfaceFailEmptyData;

    const memory = try utilsdl.errorcheck_ptr(sdl.SDL_RWops, sdl.SDL_RWFromConstMem(@ptrCast(*c_void, &data[0]), @intCast(c_int, data.len)));
    const surface = try utilsdl.errorcheck_ptr(sdl.SDL_Surface, sdl.IMG_Load_RW(memory, 1));
    defer sdl.SDL_FreeSurface(surface);
    const texture = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTextureFromSurface(tile_cache.renderer, surface));
    // TODO: should there be some limit on size of texture map cache?
    //       currently memory will just accumulate there ad-infinitum
    //defer sdl.SDL_DestroyTexture(texture);
    try tile_cache.texture_map.put(coords, texture);
    return tile_cache.texture_map.get(coords).?;
}

fn transfer_complete(tile_cache: *@This(), msg: *curl.CURLMsg) !void {
    switch (msg.data.result) {
        .CURLE_OPERATION_TIMEDOUT => {
            utildbg.log("Curl timed out for msg: {}\n", .{msg});
        },
        .CURLE_OK => {
            if (tile_cache.curl_client_to_coords(msg.*.easy_handle)) |coords| {
                const transfer_datum = tile_cache.transfer_map.get(coords).?;
                const datum_array = transfer_datum.data_arraylist.items;
                tile_cache.byte_counter += transfer_datum.data_arraylist.items.len;

                if (tile_cache.cache_dir) |cache_dir| {
                    // Save to FS
                    const path = try png_path(tile_cache.allocator, tile_cache.source_url.?, coords);
                    try cache_dir.writeFile(path, datum_array);
                }
                if (tile_cache.transfer_map.get(coords).?.load_to_texture) {
                    // Load to surface
                    _ = try tile_cache.load_data_to_texture(coords, datum_array);
                }
            } else {
                utildbg.log("Failed to find coordinates associated with downloaded data?\n", .{});
            }
        },
        else => {
            utildbg.log("Unhandled curl error code response {}\n", .{msg.data.result});
        },
    }
}

// Essentially either way, if CURLE_OK passes through or if there's
// some error we clear the item from the transfer queue and push a
// SDL resize (refresh event). By effect, if tile is loaded in texture
// map rendering thread fetches and updates it; if CURLE_OK wasn't
// there - the item will get repushed back into queue
fn transfer_cleanup(tile_cache: *@This(), client: ?*curl.CURL) !void {
    if (tile_cache.curl_client_to_coords(client)) |coords| {
        const transfer_datum = tile_cache.transfer_map.get(coords).?;
        const datum_array = transfer_datum.data_arraylist.items;
        tile_cache.transfer_map.get(coords).?.data_arraylist.deinit();
        _ = tile_cache.transfer_map.swapRemove(coords);
        tile_cache.allocator.destroy(transfer_datum);
    }

    try curl_errorcheck(curl.curl_multi_remove_handle(tile_cache.curl_multi, client));
    curl.curl_easy_cleanup(client);

    utilsdl.sdl_push_resize_event();
}

fn tile_xferinfo_curl_callback(
    user_data: *c_void,
    dl_total: curl.curl_off_t,
    dl_now: curl.curl_off_t,
    ul_total: curl.curl_off_t,
    ul_now: curl.curl_off_t,
) callconv(.C) c_uint {
    //utildbg.log("Progress: {} {}\n", .{ dl_now, dl_total });
    var tile_data = @intToPtr(*TransferDatum, @ptrToInt(user_data));
    tile_data.progress_dl_now = dl_now;
    tile_data.progress_dl_total = dl_total;
    return curl.CURL_PROGRESSFUNC_CONTINUE;
}

fn tile_write_curl_callback(
    data: *c_void,
    size: c_uint,
    nmemb: c_uint,
    user_data: *c_void,
) callconv(.C) c_uint {
    //utildbg.log("Write!!: \n", .{});
    var transfer_datum = @intToPtr(*TransferDatum, @ptrToInt(user_data));
    var typed_data = @intToPtr([*]u8, @ptrToInt(data));
    transfer_datum.data_arraylist.appendSlice(typed_data[0 .. nmemb * size]) catch return 0;
    return nmemb * size;
}

fn png_path(allocator: *std.mem.Allocator, source: []const u8, coords: types.XYZ) ![]u8 {
    var source_hash: [32:0]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &source_hash, .{});
    return try std.fmt.allocPrint(
        allocator,
        "{s}_{d}_{d}_{d}.png",
        .{ std.fmt.fmtSliceHexLower(source_hash[0..8]), coords.z, coords.x, coords.y },
    );
}

/// Downloads tiles continuously
/// If graphical_mode is true, will idle even when queue_lifo is empty.
/// If graphical_mode is false, will terminate once queue_lifo is empty.
pub fn download_loop(tile_cache: *@This(), graphical_mode: bool) void {
    const initial_queue_size = tile_cache.queue_lifo.count();
    var running: c_int = undefined;
    var n_msgs: c_int = undefined;

    while ((graphical_mode and tile_cache.download_thread != null) or
        (!graphical_mode and (tile_cache.queue_lifo.count() > 0 or tile_cache.transfer_map.count() > 0)))
    {
        curl_errorcheck(curl.curl_multi_perform(tile_cache.curl_multi, &running)) catch unreachable;
        var msg: ?*curl.CURLMsg = curl.curl_multi_info_read(tile_cache.curl_multi, &n_msgs);
        while (msg != null and tile_cache.download_thread != null) {
            switch (msg.?.*.msg) {
                ._DONE => {
                    if (graphical_mode and sdl.SDL_HasEvents(0, 99999999) == sdl.SDL_bool.SDL_TRUE) continue;
                    const lock = tile_cache.mutex.acquire();
                    tile_cache.transfer_complete(msg.?) catch |err| {
                        utildbg.log("Failed to successfully complete transfer: {}!\n", .{err});
                    };
                    tile_cache.transfer_cleanup(msg.?.easy_handle) catch |err| {
                        utildbg.log("Failed to successfully cleanup transfer: {}!\n", .{err});
                    };
                    lock.release();
                },
                else => {
                    // Will timeout and trigger ._DONE in anycase
                },
            }
            curl_errorcheck(curl.curl_multi_perform(tile_cache.curl_multi, &running)) catch unreachable;
            msg = curl.curl_multi_info_read(tile_cache.curl_multi, &n_msgs);
        }

        while (tile_cache.queue_lifo.count() > 0 and tile_cache.transfer_map.count() < tile_cache.max_n_transfers) {
            if (graphical_mode and sdl.SDL_HasEvents(0, 99999999) == sdl.SDL_bool.SDL_TRUE) continue;
            const lock = tile_cache.mutex.acquire();
            var coords = tile_cache.queue_lifo.pop();
            tile_cache.add_to_curl_multi(coords.key, coords.value) catch unreachable;
            lock.release();
        }

        // Progress indicator for non graphical mode
        if (!graphical_mode) {
            std.debug.warn("\x1b[1;1H\x1b[2J", .{});
            std.debug.warn(
                \\Mepo - download mode
                \\====================
                \\Progress: {d:.2}% ({}/{} tiles downloaded)
                \\Bandwidth used: {} megabytes
                \\
            ,
                .{
                    100.0 * (@intToFloat(f32, initial_queue_size - tile_cache.queue_lifo.count()) /
                        @intToFloat(f32, initial_queue_size)),
                    initial_queue_size - tile_cache.queue_lifo.count(),
                    initial_queue_size,
                    tile_cache.byte_counter / 1024 / 1024,
                },
            );
        }

        curl_errorcheck(curl.curl_multi_poll(tile_cache.curl_multi, undefined, 0, config.DownloaderPollMs, null)) catch |e| {
            utildbg.log("Curl multi wait fail: {}\n", .{e});
        };
    }

    if (tile_cache.download_thread == null) {
        for (tile_cache.transfer_map.keys()) |transfer_key| {
            if (tile_cache.transfer_map.get(transfer_key)) |transfer| {
                tile_cache.transfer_cleanup(transfer.client) catch |err| {
                    utildbg.log("Failed to cleanup inprogress transfer on thread terminate: {}", .{err});
                };
            }
        }
    }
}

pub fn download_loop_sdl_threadable(userdata: ?*c_void) callconv(.C) c_int {
    var tile_cache = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata.?));
    tile_cache.download_loop(true);
    return 0;
}

pub fn set_network(tile_cache: *@This(), enable: bool) void {
    if (!enable and tile_cache.download_thread != null) {
        const orphan_thread = tile_cache.download_thread.?;
        tile_cache.download_thread = null;
        tile_cache.queue_lifo.clearAndFree();
        sdl.SDL_WaitThread(orphan_thread, null);
    } else if (enable and tile_cache.download_thread == null) {
        tile_cache.download_thread = sdl.SDL_CreateThread(
            download_loop_sdl_threadable,
            "Tile_Download_Thread",
            tile_cache,
        );
    }
}

pub fn set_cache_dir(tile_cache: *@This(), path: [:0]const u8) !void {
    const expanded_path = try utilfile.wordexp_filepath(tile_cache.allocator, path);
    defer tile_cache.allocator.free(expanded_path);
    try std.fs.cwd().makePath(expanded_path);
    tile_cache.cache_dir = try std.fs.cwd().openDir(expanded_path, .{ .iterate = true });
}

/// Sets the cache URL, making copy of str
///
/// Caller passed ptr url may be safely freed
pub fn set_cache_url(tile_cache: *@This(), url: [:0]const u8) !void {
    // Empty Cache
    const lock = tile_cache.mutex.acquire();
    for (tile_cache.texture_map.values()) |texture| {
        sdl.SDL_DestroyTexture(texture);
    }
    tile_cache.texture_map.clearAndFree();
    tile_cache.queue_lifo.clearAndFree();
    defer lock.release();

    // Set new URL
    if (tile_cache.source_url) |present_source_url| {
        tile_cache.allocator.free(present_source_url);
    }
    tile_cache.source_url = try tile_cache.allocator.dupeZ(u8, url);

    // Resize
    utilsdl.sdl_push_resize_event();
}

pub fn set_renderer(tile_cache: *@This(), renderer: *sdl.SDL_Renderer) void {
    tile_cache.renderer = renderer;
}

pub fn set_max_n_transfers(tile_cache: *@This(), max_n_transfers: usize) void {
    tile_cache.max_n_transfers = max_n_transfers;
}

pub fn init(allocator: *std.mem.Allocator) anyerror!@This() {
    if (curl.curl_multi_init()) |curl_multi| {
        return @as(@This(), .{
            .allocator = allocator,
            .cache_dir = null,
            .curl_multi = curl.curl_multi_init().?,
            .download_thread = null,
            .mutex = std.Thread.Mutex{},
            .queue_lifo = datastructure.Lifo(types.XYZ, bool).init(allocator),
            .renderer = null,
            .source_url = null,
            .texture_map = std.array_hash_map.AutoArrayHashMap(types.XYZ, *sdl.SDL_Texture).init(allocator),
            .transfer_map = std.array_hash_map.AutoArrayHashMap(types.XYZ, *TransferDatum).init(allocator),
        });
    } else {
        return error.MultiInitFail;
    }
}

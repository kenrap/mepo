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
const p = @import("./util/utilprefs.zig");
const datastructure = @import("./datastructure/datastructure.zig");

pub const DownloadBBoxRequest = struct {
    a_lat: f64,
    a_lon: f64,
    b_lat: f64,
    b_lon: f64,
    zoom_min: i32,
    zoom_max: i32,
};
const TransferDatum = struct {
    client: *curl.CURL,
    coords: types.XYZ,
    data_arraylist: std.ArrayList(u8),
    progress_dl_now: ?c_long,
    progress_dl_total: ?c_long,
    load_to_texture: bool,
};
const TileData = union(TileDataTag) {
    transfer_datum: TransferDatum,
    texture: *sdl.SDL_Texture,
    queued_position: u32,
    error_type: enum { Offline },
};
const TileDataTag = enum { transfer_datum, texture, queued_position, error_type };
const QueuedInfo = struct { n_queued: usize, n_cached: usize };

allocator: std.mem.Allocator,
dev_null_fd: ?*cstdio.FILE,
thread_download: ?*sdl.SDL_Thread = null,
thread_queuebbox: ?*sdl.SDL_Thread = null,
bbox_queue: ?DownloadBBoxRequest = null,
byte_counter: u64 = 0,
cache_dir: ?std.fs.Dir = null,
curl_multi: *curl.CURLM,
queue_lifo_ui: datastructure.QueueHashMap(types.XYZ, void),
queue_lifo_bg: datastructure.QueueHashMap(types.XYZ, void),
renderer: ?*sdl.SDL_Renderer = null,
surface_map: datastructure.QueueHashMap(types.XYZ, *sdl.SDL_Surface),
texture_map: datastructure.EvictionHashMap(types.XYZ, *sdl.SDL_Texture, evict_texture, &config.MaxTextures),
transfer_map: datastructure.QueueHashMap(types.XYZ, *TransferDatum),

/// Downloads tiles continuously
/// If graphical_mode is true, will idle even when queue_lifo is empty.
/// If graphical_mode is false, will terminate once queue_lifo is empty.
pub fn download_loop(tile_cache: *@This(), graphical_mode: bool) !void {
    const initial_queue_bg_size = tile_cache.queue_lifo_bg.count();
    var ui_last_update_ticks = sdl.SDL_GetTicks();
    var running: c_int = undefined;
    var n_msgs: c_int = undefined;

    while (tile_cache.download_loop_should_continue(graphical_mode)) {
        // 1. Use curl multi interface to loop through completed transfers
        //    transfers out to textures & cleans up
        curl_processing_loop: while (tile_cache.download_loop_should_continue(graphical_mode)) {
            try curl_errorcheck(curl.curl_multi_perform(tile_cache.curl_multi, &running));
            if (curl.curl_multi_info_read(tile_cache.curl_multi, &n_msgs)) |msg| {
                if (msg.*.msg == curl.CURLMSG_DONE) {
                    tile_cache.download_loop_transfer_complete(msg) catch |err| {
                        utildbg.log("Failed to successfully complete transfer: {}!\n", .{err});
                    };
                    tile_cache.download_loop_transfer_cleanup(msg.*.easy_handle) catch |err| {
                        utildbg.log("Failed to successfully cleanup transfer: {}!\n", .{err});
                    };
                }
            } else break :curl_processing_loop;
        }

        // 2. Transfer from UI LIFO into transfers
        while (tile_cache.queue_lifo_ui.count() > 0 and tile_cache.transfer_map.count() < p.get(p.pref.tile_cache_max_n_transfers).u) {
            var coords = tile_cache.queue_lifo_ui.pop();
            try tile_cache.curl_add_to_multi_and_register_transfer(coords.key, true);
        }

        // 3. Transfer from BG LIFO into transfers
        while (tile_cache.queue_lifo_bg.count() > 0 and tile_cache.transfer_map.count() < p.get(p.pref.tile_cache_max_n_transfers).u) {
            var coords = tile_cache.queue_lifo_bg.pop();
            try tile_cache.curl_add_to_multi_and_register_transfer(coords.key, false);
        }

        // 4. Print status message if non graphical
        if (!graphical_mode) tile_cache.download_loop_progress_indicator(initial_queue_bg_size);

        // 5. Idle and poll on curl multi
        curl_errorcheck(curl.curl_multi_poll(tile_cache.curl_multi, undefined, 0, config.DownloaderPollMs, null)) catch |e| {
            utildbg.log("Curl multi poll fail: {}\n", .{e});
        };

        // 6. Refresh UI if greater then threshold
        if (graphical_mode and sdl.SDL_GetTicks() > ui_last_update_ticks + 1000) {
            ui_last_update_ticks = sdl.SDL_GetTicks();
            utilsdl.sdl_push_event_resize();
        }
    }

    // Purge out in-progress transfers on thread termination
    while (tile_cache.transfer_map.count() > 0) {
        tile_cache.download_loop_transfer_cleanup(tile_cache.transfer_map.values()[0].client) catch |e| {
            utildbg.log("Failed to cleanup in-progress transfer on download thread termination: {}\n", .{e});
        };
    }
}

/// Sets the cache URL, making copy of str
/// Caller passed ptr url may be safely freed
pub fn set_cache_url(tile_cache: *@This(), url: [:0]const u8) !void {
    if (tile_cache.thread_download != null) {
        // Set's network off (cancels inprogress transfers, resumes on switch)
        tile_cache.set_network(false);
        defer tile_cache.set_network(true);
    }
    defer utilsdl.sdl_push_event_resize();

    // Empty texture map, surface map, & queues
    for (tile_cache.texture_map.values()) |t| sdl.SDL_DestroyTexture(t);
    for (tile_cache.surface_map.values()) |s| sdl.SDL_FreeSurface(s);
    tile_cache.texture_map.clearAndFree();
    tile_cache.surface_map.clearAndFree();
    tile_cache.queue_lifo_ui.clearAndFree();
    tile_cache.queue_lifo_bg.clearAndFree();

    try p.set_t(tile_cache.allocator, p.pref.tile_cache_url, url);
}

pub fn set_cache_dir(tile_cache: *@This(), path: [:0]const u8) !void {
    try p.set_t(tile_cache.allocator, p.pref.tile_cache_dir, path);

    const expanded_path = try utilfile.wordexp_filepath(tile_cache.allocator, p.get(p.pref.tile_cache_dir).t.?);
    defer tile_cache.allocator.free(expanded_path);
    try std.fs.cwd().makePath(expanded_path);
    tile_cache.cache_dir = try std.fs.cwd().openDir(expanded_path, .{ .access_sub_paths = true });
}

/// E.g. esentially the one function responsibel for launching/termination
/// of the download thread
pub fn set_network(tile_cache: *@This(), enable: bool) void {
    tile_cache.set_queue(null);
    if (!enable and tile_cache.thread_download != null) {
        const orphan_thread = tile_cache.thread_download.?;
        tile_cache.thread_download = null;
        sdl.SDL_WaitThread(orphan_thread, null);
    } else if (enable and tile_cache.thread_download == null) {
        tile_cache.thread_download = sdl.SDL_CreateThread(
            threadable_download_loop_sdl,
            "Tile_Download_Thread",
            tile_cache,
        );
    }
}

/// E.g. essentially the one function responsible for launching/termination
/// of the queuer thread
pub fn set_queue(tile_cache: *@This(), dl_req_opt: ?DownloadBBoxRequest) void {
    // Cancel any existing queueing thread
    if (tile_cache.thread_queuebbox) |thread_queuebbox| {
        const orphan_thread = thread_queuebbox;
        tile_cache.thread_queuebbox = null;
        sdl.SDL_WaitThread(orphan_thread, null);
    }

    // Purge queue
    tile_cache.queue_lifo_ui.clearAndFree();
    tile_cache.queue_lifo_bg.clearAndFree();

    // Launch new thread if requesting download
    if (dl_req_opt) |dl_req| {
        tile_cache.bbox_queue = dl_req;
        tile_cache.thread_queuebbox = sdl.SDL_CreateThread(
            threadable_tile_bg_bbox_queue,
            "Queueing_Thread",
            tile_cache,
        );
    }
}

pub fn tile_bg_bbox_queue(tile_cache: *@This(), dl_req: DownloadBBoxRequest, cancellable: bool) !QueuedInfo {
    if (cancellable and tile_cache.thread_download == null) return error.NoDownloadThread;

    const lat_min = if (dl_req.a_lat < dl_req.b_lat) dl_req.a_lat else dl_req.b_lat;
    const lat_max = if (dl_req.a_lat > dl_req.b_lat) dl_req.a_lat else dl_req.b_lat;
    const lon_min = if (dl_req.a_lon < dl_req.b_lon) dl_req.a_lon else dl_req.b_lon;
    const lon_max = if (dl_req.a_lon > dl_req.b_lon) dl_req.a_lon else dl_req.b_lon;

    if (dl_req.zoom_min > dl_req.zoom_max or
        dl_req.zoom_max < 0 or
        dl_req.zoom_max > 19 or
        dl_req.zoom_min < 0 or
        dl_req.zoom_min > 19) return error.InvalidZoomRange;

    var n_cached: usize = 0;
    var n_queued: usize = 0;

    var z: u32 = @intCast(u32, dl_req.zoom_min);
    while (z <= dl_req.zoom_max) : (z += 1) {
        const x_min = @divFloor(utilconversion.lon_to_px_x(lon_min, z), config.Tsize);
        const x_max = @divFloor(utilconversion.lon_to_px_x(lon_max, z), config.Tsize);
        const y_min = @divFloor(utilconversion.lat_to_px_y(lat_max, z), config.Tsize);
        const y_max = @divFloor(utilconversion.lat_to_px_y(lat_min, z), config.Tsize);
        var x: i32 = x_min;
        while (x <= x_max) : (x += 1) {
            var y: i32 = y_min;
            while (y <= y_max) : (y += 1) {
                utildbg.log("Tile cache queueing x={d} y={d} z={d}\n", .{ x, y, z });
                if (cancellable and tile_cache.thread_queuebbox == null) return error.EarlyQueueBboxTermination;

                if (x < 0 or y < 0 or z < 0) continue;
                const coords = .{ .x = @intCast(u32, x), .y = @intCast(u32, y), .z = @intCast(u8, z) };
                if (try tile_cache.tile_exists_in_fs_and_non_expired(coords)) {
                    n_cached += 1;
                } else {
                    n_queued += 1;
                    try tile_cache.queue_lifo_bg.put(coords, void{});
                }
            }
        }
    }

    return QueuedInfo{
        .n_cached = n_cached,
        .n_queued = n_queued,
    };
}

/// Retreives a tile from cache
/// If tile is not present & will queue tile to be downloaded if downloading
/// thread is present. This function is only ever called from Mepo's primary
/// thread and thus is safe to use renderer functions within (e.g. we transfer
/// the SDL surface into a texture here)
/// TODO: maybe just move this fn/code wholesale into Mepo.zig?
pub fn tile_ui_retreive_or_queue(tile_cache: *@This(), coords: types.XYZ) !TileData {
    var file_cached_png_opt: ?[]u8 = null;

    if (tile_cache.texture_map.get(coords)) |texture| {
        return TileData{ .texture = texture };
    } else if (tile_cache.transfer_map.get(coords)) |transfer| {
        return TileData{ .transfer_datum = transfer.* };
    } else if (tile_cache.surface_map.get(coords)) |surface| {
        defer sdl.SDL_FreeSurface(surface);
        const texture = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTextureFromSurface(tile_cache.renderer, surface));
        _ = tile_cache.surface_map.swapRemove(coords);
        _ = try tile_cache.texture_map.put(coords, texture);
        return TileData{ .texture = texture };
    } else if (tile_cache.cache_dir) |cache_dir| load_from_fs: {
        if (!try tile_cache.tile_exists_in_fs_and_non_expired(coords)) break :load_from_fs;
        const png_fs_path = try png_path(tile_cache.allocator, p.get(p.pref.tile_cache_url).t.?, coords);
        defer tile_cache.allocator.free(png_fs_path);

        file_cached_png_opt = cache_dir.readFileAlloc(tile_cache.allocator, png_fs_path, 500000) catch |err| b: {
            utildbg.log("Unable to alloc space for PNG: {}\n", .{err});
            break :b null;
        };

        if (file_cached_png_opt) |file_cached_png| {
            defer tile_cache.allocator.free(file_cached_png);
            const surface = tile_cache.load_data_to_surface(file_cached_png) catch |err| {
                utildbg.log("Errored when loading data for tile {} from FS (file: {s}) to SDL Surface: {}\n", .{coords, png_fs_path, err});
                break :load_from_fs;
            };
            try tile_cache.surface_map.put(coords, surface);
        }
    }


    if (tile_cache.thread_download == null) {
        return TileData{ .error_type = .Offline };
    } else {
        try tile_cache.queue_lifo_ui.put(coords, void{});
        return TileData{
            .queued_position = @intCast(u32, if (tile_cache.queue_lifo_ui.getIndex(coords)) |index| index else 0),
        };
    }
}

// ////////////////////////////////////////////////////////////////////////////
// Private

fn curl_add_to_multi_and_register_transfer(tile_cache: *@This(), coords: types.XYZ, load_to_texture: bool) !void {
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
        var url = try tile_cache.allocator.alloc(u8, p.get(p.pref.tile_cache_url).t.?.len + (3 * 10));
        if (cstdio.sprintf(
            &url[0],
            &p.get(p.pref.tile_cache_url).t.?[0],
            @intCast(c_int, coords.x),
            @intCast(c_int, coords.y),
            @intCast(c_int, coords.z),
        ) < 0) return error.TileURLSprintfFail;
        break :url url;
    };
    defer tile_cache.allocator.free(tile_url);

    try curl_setopt(transfer_datum.client, curl.CURLOPT_NOPROGRESS, @intCast(c_long, 0));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_NOSIGNAL, @intCast(c_long, 1));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_CONNECTTIMEOUT, @intCast(c_long, config.DownloadTimeoutSeconds));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_TIMEOUT, @intCast(c_long, config.DownloadTimeoutSeconds));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_URL, @ptrCast(*anyopaque, tile_url));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_USERAGENT, config.DownloadUseragent);
    try curl_setopt(transfer_datum.client, curl.CURLOPT_VERBOSE, @intCast(c_long, 0));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_WRITEDATA, transfer_datum);
    try curl_setopt(transfer_datum.client, curl.CURLOPT_WRITEFUNCTION, curl_callback_tile_write);
    try curl_setopt(transfer_datum.client, curl.CURLOPT_XFERINFODATA, transfer_datum);
    try curl_setopt(transfer_datum.client, curl.CURLOPT_VERBOSE, @intCast(c_long, 0));
    try curl_setopt(transfer_datum.client, curl.CURLOPT_STDERR, tile_cache.dev_null_fd);
    try curl_setopt(transfer_datum.client, curl.CURLOPT_XFERINFOFUNCTION, curl_callback_tile_xferinfo);
    try curl_errorcheck(curl.curl_multi_add_handle(tile_cache.curl_multi, transfer_datum.client));
    utildbg.log("Add multi handle {any}\n", .{coords});
}

fn curl_callback_tile_xferinfo(
    user_data: *anyopaque,
    dl_total: curl.curl_off_t,
    dl_now: curl.curl_off_t,
    ul_total: curl.curl_off_t,
    ul_now: curl.curl_off_t,
) callconv(.C) c_uint {
    //utildbg.log("Progress: {} {}\n", .{ dl_now, dl_total });
    _ = ul_total;
    _ = ul_now;
    var tile_data = @intToPtr(*TransferDatum, @ptrToInt(user_data));
    tile_data.progress_dl_now = dl_now;
    tile_data.progress_dl_total = dl_total;
    return curl.CURL_PROGRESSFUNC_CONTINUE;
}

fn curl_callback_tile_write(
    data: *anyopaque,
    size: c_uint,
    nmemb: c_uint,
    user_data: *anyopaque,
) callconv(.C) c_uint {
    //utildbg.log("Write!!: \n", .{});
    var transfer_datum = @intToPtr(*TransferDatum, @ptrToInt(user_data));
    var typed_data = @intToPtr([*]u8, @ptrToInt(data));
    transfer_datum.data_arraylist.appendSlice(typed_data[0 .. nmemb * size]) catch return 0;
    return nmemb * size;
}

fn curl_errorcheck(response: curl.CURLMcode) !void {
    if (response == curl.CURLM_OK) return;
    return error.CurlMultiFail;
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

fn curl_setopt(client: *curl.CURL, opt: c_int, value: anytype) !void {
    if (curl.curl_easy_setopt(client, @intCast(c_uint, opt), value) != curl.CURLE_OK)
        return error.CurlEasySetOptFail;
}

/// Show progress indicator for the download loop (for non interactive downloading)
fn download_loop_progress_indicator(tile_cache: *@This(), initial_queue_size: usize) void {
    std.debug.print("\x1b[1;1H\x1b[2J", .{});
    std.debug.print(
        \\Mepo - download mode
        \\====================
        \\Progress: {d:.2}% ({}/{} tiles downloaded)
        \\Bandwidth used: {} megabytes
        \\
    ,
        .{
            100.0 * (@intToFloat(f32, initial_queue_size - tile_cache.queue_lifo_bg.count()) /
                @intToFloat(f32, initial_queue_size)),
            initial_queue_size - tile_cache.queue_lifo_bg.count(),
            initial_queue_size,
            tile_cache.byte_counter / 1024 / 1024,
        },
    );
}

/// Determine whether the download loop should continue based on either
/// if in graphical mode or non-empty queu
fn download_loop_should_continue(tile_cache: *@This(), graphical_mode: bool) bool {
    const graphical_and_online = (graphical_mode and tile_cache.thread_download != null);
    const nongraphical_and_pending = (!graphical_mode and (tile_cache.queue_lifo_bg.count() > 0 or tile_cache.transfer_map.count() > 0));
    return graphical_and_online or nongraphical_and_pending;
}

fn download_loop_transfer_complete(tile_cache: *@This(), msg: *curl.CURLMsg) !void {
    switch (msg.data.result) {
        curl.CURLE_OPERATION_TIMEDOUT => {
            utildbg.log("Curl timed out for msg: {}\n", .{msg});
        },
        curl.CURLE_OK => {
            if (tile_cache.curl_client_to_coords(msg.*.easy_handle)) |coords| {
                const transfer_datum = tile_cache.transfer_map.get(coords).?;
                const datum_array = transfer_datum.data_arraylist.items;
                tile_cache.byte_counter += transfer_datum.data_arraylist.items.len;

                if (tile_cache.cache_dir) |cache_dir| {
                    const memory = try utilsdl.errorcheck_ptr(
                        sdl.SDL_RWops,
                        sdl.SDL_RWFromConstMem(@ptrCast(*anyopaque, &datum_array[0]), @intCast(c_int, datum_array.len)),
                    );
                    const is_valid_png_data = sdl.SDL_TRUE == sdl.IMG_isPNG(memory);
                    try utilsdl.errorcheck(sdl.SDL_RWclose(memory));

                    // Save to FS
                    if (is_valid_png_data) {
                        const path = try png_path(tile_cache.allocator, p.get(p.pref.tile_cache_url).t.?, coords);
                        try cache_dir.writeFile(path, datum_array);
                    }
                }
                if (tile_cache.transfer_map.get(coords).?.load_to_texture) {
                    // Load to surface
                    _ = try tile_cache.load_data_to_surface(datum_array);
                    utilsdl.sdl_push_event_resize();
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

/// Essentially either way, if CURLE_OK passes through or if there's
/// some error we clear the item from the transfer queue and push a
/// SDL resize (refresh event). By effect, if tile is loaded in texture
/// map rendering thread fetches and updates it; if CURLE_OK wasn't
/// there - the item will get repushed back into queue
fn download_loop_transfer_cleanup(tile_cache: *@This(), client: ?*curl.CURL) !void {
    if (tile_cache.curl_client_to_coords(client)) |coords| {
        const transfer_datum = tile_cache.transfer_map.get(coords).?;
        tile_cache.transfer_map.get(coords).?.data_arraylist.deinit();
        _ = tile_cache.transfer_map.swapRemove(coords);
        tile_cache.allocator.destroy(transfer_datum);

        try curl_errorcheck(curl.curl_multi_remove_handle(tile_cache.curl_multi, client));
        curl.curl_easy_cleanup(client);
    }
}

fn evict_texture(_: types.XYZ, texture: *sdl.SDL_Texture) void {
    sdl.SDL_DestroyTexture(texture);
}

fn load_data_to_surface(_: *@This(), data: []u8) !*sdl.SDL_Surface {
    if (data.len == 0) return error.LoadToSurfaceFailEmptyData;

    const memory = try utilsdl.errorcheck_ptr(sdl.SDL_RWops, sdl.SDL_RWFromConstMem(@ptrCast(*anyopaque, &data[0]), @intCast(c_int, data.len)));
    return try utilsdl.errorcheck_ptr(sdl.SDL_Surface, sdl.IMG_Load_RW(memory, 1));
}

fn png_path(allocator: std.mem.Allocator, source: []const u8, coords: types.XYZ) ![]u8 {
    var source_hash: [32:0]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &source_hash, .{});
    return try std.fmt.allocPrint(
        allocator,
        "{s}_{d}_{d}_{d}.png",
        .{ std.fmt.fmtSliceHexLower(source_hash[0..8]), coords.z, coords.x, coords.y },
    );
}

/// Check whether tile is already in the filesystem and not expired according
/// to creation time & expiry seconds setting
fn tile_exists_in_fs_and_non_expired(tile_cache: *@This(), coords: types.XYZ) !bool {
    if (tile_cache.cache_dir) |cache_dir| {
        const png = try png_path(tile_cache.allocator, p.get(p.pref.tile_cache_url).t.?, coords);
        defer tile_cache.allocator.free(png);
        const tile_file = cache_dir.openFile(png, .{}) catch return false;
        defer tile_file.close();
        const expiry_seconds = @floatToInt(i32, p.get(p.pref.tile_cache_expiry_seconds).f);
        if (expiry_seconds < 0 or std.time.timestamp() < (try tile_file.stat()).ctime + expiry_seconds) {
            return true;
        }
    }
    return false;
}

fn threadable_tile_bg_bbox_queue(userdata: ?*anyopaque) callconv(.C) c_int {
    var tile_cache = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata.?));
    if (tile_cache.tile_bg_bbox_queue(tile_cache.bbox_queue.?, true)) |q| {
        utildbg.log("Done: {}\n", .{q});
    } else |err| {
        utildbg.log("Error running bbox loop: {}\n", .{err});
    }

    return 0;
}

fn threadable_download_loop_sdl(userdata: ?*anyopaque) callconv(.C) c_int {
    var tile_cache = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata.?));
    tile_cache.download_loop(true) catch |e| {
        utildbg.log("Error running download loop: {}\n", .{e});
    };
    return 0;
}

pub fn init(allocator: std.mem.Allocator) anyerror!@This() {
    if (curl.curl_multi_init()) |_| {
        var tc = @as(@This(), .{
            .allocator = allocator,
            .dev_null_fd = cstdio.fopen("/dev/null", "wb"),
            .curl_multi = curl.curl_multi_init().?,
            .queue_lifo_ui = datastructure.QueueHashMap(types.XYZ, void).init(allocator),
            .queue_lifo_bg = datastructure.QueueHashMap(types.XYZ, void).init(allocator),
            .surface_map = datastructure.QueueHashMap(types.XYZ, *sdl.SDL_Surface).init(allocator),
            .texture_map = datastructure.EvictionHashMap(types.XYZ, *sdl.SDL_Texture, evict_texture, &config.MaxTextures).init(allocator),
            .transfer_map = datastructure.QueueHashMap(types.XYZ, *TransferDatum).init(allocator),
        });
        try tc.set_cache_url(try allocator.dupeZ(u8, "https://tile.openstreetmap.org/%3$d/%1$d/%2$d.png"));
        return tc;
    } else {
        return error.MultiInitFail;
    }
}

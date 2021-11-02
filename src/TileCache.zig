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
const utilfile = @import("./util/utilfile.zig");
const utildbg = @import("./util/utildbg.zig");
const datastructure = @import("./datastructure/datastructure.zig");

pub const TransferDatum = struct {
    client: *curl.CURL,
    coords: types.TileSpec,
    data_arraylist: std.ArrayList(u8),
    progress_dl_now: ?c_long,
    progress_dl_total: ?c_long,
    load_to_texture: bool,
};
const TileDataTag = enum {
    transfer_datum,
    texture,
    queued_position,
};
pub const TileData = union(TileDataTag) {
    transfer_datum: TransferDatum,
    texture: *sdl.SDL_Texture,
    queued_position: u32,
};

allocator: *std.mem.Allocator,
cache_dir: ?std.fs.Dir,
curl_multi: *curl.CURLM,
mutex: std.Thread.Mutex,
n_current_transfers: u32,
queue_lifo: datastructure.Lifo(types.TileSpec, bool),
renderer: ?*sdl.SDL_Renderer,
source_url: ?[:0]const u8,
texture_map: std.array_hash_map.AutoArrayHashMap(types.TileSpec, *sdl.SDL_Texture),
transfer_map: std.array_hash_map.AutoArrayHashMap(types.TileSpec, *TransferDatum),

pub fn tile_retrieve(tile_cache: *@This(), coords: types.TileSpec) !TileData {
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

    try tile_cache.queue_lifo.put(coords, true);

    return TileData{
        .queued_position = @intCast(u32, if (tile_cache.queue_lifo.getIndex(coords)) |index| index else 0),
    };
}

pub fn tile_queue_no_surface_load(tile_cache: *@This(), coords: types.TileSpec) !void {
    const lock = tile_cache.mutex.acquire();
    defer lock.release();

    if (tile_cache.cache_dir) |cache_dir| check_tile_exists: {
        const png = try png_path(tile_cache.allocator, tile_cache.source_url.?, coords);
        defer tile_cache.allocator.free(png);
        cache_dir.access(png, .{}) catch {
            break :check_tile_exists;
        };
        return;
    }

    try tile_cache.queue_lifo.put(coords, false);
}

fn add_to_curl_multi(tile_cache: *@This(), coords: types.TileSpec, load_to_texture: bool) !void {
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

fn curl_msg_to_coords(tile_cache: *@This(), msg: *curl.CURLMsg) ?types.TileSpec {
    var it = tile_cache.transfer_map.iterator();
    while (it.next()) |kv| {
        if (kv.value_ptr.*.client == msg.*.easy_handle) {
            return kv.value_ptr.*.coords;
        }
    }
    return null;
}

fn load_data_to_texture(tile_cache: *@This(), coords: types.TileSpec, data: []u8) !*sdl.SDL_Texture {
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
            if (tile_cache.curl_msg_to_coords(msg)) |coords| {
                const transfer_datum = tile_cache.transfer_map.get(coords).?;
                const datum_array = transfer_datum.data_arraylist.items;

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
fn transfer_cleanup(tile_cache: *@This(), msg: *curl.CURLMsg) !void {
    if (tile_cache.curl_msg_to_coords(msg)) |coords| {
        const transfer_datum = tile_cache.transfer_map.get(coords).?;
        const datum_array = transfer_datum.data_arraylist.items;
        tile_cache.transfer_map.get(coords).?.data_arraylist.deinit();
        _ = tile_cache.transfer_map.swapRemove(coords);
        tile_cache.allocator.destroy(transfer_datum);
    }

    try curl_errorcheck(curl.curl_multi_remove_handle(tile_cache.curl_multi, msg.*.easy_handle));

    curl.curl_easy_cleanup(msg.*.easy_handle);

    if (tile_cache.n_current_transfers > 0) {
        tile_cache.n_current_transfers -= 1;
    }
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

fn png_path(allocator: *std.mem.Allocator, source: []const u8, coords: types.TileSpec) ![]u8 {
    var source_hash: [32:0]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &source_hash, .{});
    return try std.fmt.allocPrint(
        allocator,
        "{s}_{d}_{d}_{d}.png",
        .{ std.fmt.fmtSliceHexLower(source_hash[0..8]), coords.z, coords.x, coords.y },
    );
}

fn download_loop(tile_cache: *@This()) void {
    var running: c_int = undefined;
    var n_msgs: c_int = undefined;

    while (true) {
        curl_errorcheck(curl.curl_multi_perform(tile_cache.curl_multi, &running)) catch unreachable;
        var msg = curl.curl_multi_info_read(tile_cache.curl_multi, &n_msgs);
        while (msg != null) {
            switch (msg.*.msg) {
                ._DONE => {
                    if (sdl.SDL_HasEvents(0, 99999999) == sdl.SDL_bool.SDL_TRUE) continue;
                    const lock = tile_cache.mutex.acquire();
                    tile_cache.transfer_complete(msg) catch |err| {
                        utildbg.log("Failed to successfully complete transfer: {}!\n", .{err});
                    };
                    tile_cache.transfer_cleanup(msg) catch |err| {
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

        while (tile_cache.queue_lifo.count() > 0 and tile_cache.n_current_transfers < config.MaxNTransfers) {
            if (sdl.SDL_HasEvents(0, 99999999) == sdl.SDL_bool.SDL_TRUE) continue;
            const lock = tile_cache.mutex.acquire();
            var coords = tile_cache.queue_lifo.pop();
            tile_cache.add_to_curl_multi(coords.key, coords.value) catch unreachable;
            tile_cache.n_current_transfers += 1;
            lock.release();
        }

        curl_errorcheck(curl.curl_multi_poll(tile_cache.curl_multi, undefined, 0, config.DownloaderPollMs, null)) catch |e| {
            utildbg.log("Curl multi wait fail: {}\n", .{e});
        };
    }
}

pub fn download_loop_sdl_threadable(userdata: ?*c_void) callconv(.C) c_int {
    var tile_cache = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata.?));
    tile_cache.download_loop();
    return 0;
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
    tile_cache.texture_map.clearAndFree();
    tile_cache.queue_lifo.clearAndFree();

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

pub fn init(allocator: *std.mem.Allocator) anyerror!@This() {
    if (curl.curl_multi_init()) |curl_multi| {
        return @as(@This(), .{
            .mutex = std.Thread.Mutex{},
            .allocator = allocator,
            .source_url = null,
            .cache_dir = null,
            .renderer = null,
            .n_current_transfers = 0,
            .transfer_map = std.array_hash_map.AutoArrayHashMap(types.TileSpec, *TransferDatum).init(allocator),
            .texture_map = std.array_hash_map.AutoArrayHashMap(types.TileSpec, *sdl.SDL_Texture).init(allocator),
            .queue_lifo = datastructure.Lifo(types.TileSpec, bool).init(allocator),
            .curl_multi = curl.curl_multi_init().?,
        });
    } else {
        return error.MultiInitFail;
    }
}

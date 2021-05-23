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
const sdlutil = @import("./util/sdlutil.zig");

pub const TransferDatum = struct {
    client: *curl.CURL,
    coords: types.TileSpec,
    data: std.ArrayList(u8),
    progress_dl_now: ?c_long,
    progress_dl_total: ?c_long,
};

pub const TileData = struct {
    transfer_datum: ?TransferDatum,
    surface: ?*sdl.SDL_Surface,
};

source_url: ?[:0]const u8,
cache_dir: ?std.fs.Dir,
n_current_transfers: u32,
queue: std.ArrayList(types.TileSpec),
map: std.array_hash_map.AutoArrayHashMap(types.TileSpec, TileData),
curl_multi: *curl.CURLM,

fn tile_xferinfo_curl_callback(user_data: *c_void, dl_total: curl.curl_off_t, dl_now: curl.curl_off_t, ul_total: curl.curl_off_t, ul_now: curl.curl_off_t) callconv(.C) c_uint {
    //std.debug.warn("Progress: {} {}\n", .{ dl_now, dl_total });
    var tile_data = @intToPtr(*TileData, @ptrToInt(user_data));
    tile_data.transfer_datum.?.progress_dl_now = dl_now;
    tile_data.transfer_datum.?.progress_dl_total = dl_total;
    return curl.CURL_PROGRESSFUNC_CONTINUE;
}

fn tile_write_curl_callback(data: *c_void, size: c_uint, nmemb: c_uint, user_data: *c_void) callconv(.C) c_uint {
    std.debug.warn("Got some bytes in download for tile {}\n", .{user_data});
    var tile_data = @intToPtr(*TileData, @ptrToInt(user_data));
    var typed_data = @intToPtr([*]u8, @ptrToInt(data));
    tile_data.transfer_datum.?.data.appendSlice(typed_data[0 .. nmemb * size]) catch return 0;
    return nmemb * size;
}

fn png_path(source: []const u8, x: u32, y: u32, z: u32) ![]u8 {
  var source_hash : [32:0]u8 = undefined;
  std.crypto.hash.sha2.Sha256.hash(source, &source_hash, .{});
  return try std.fmt.allocPrint(std.heap.c_allocator, "{s}_{}_{}_{}.png", .{ source_hash[0..8], z, x, y });
}


pub fn tile_retrieve(tile_cache: *@This(), pixel_format: *sdl.SDL_PixelFormat, coords: types.TileSpec) !TileData {
    var file_cached_png_opt: ?[]u8 = null;

    if (tile_cache.map.get(coords)) |tile| {
        return tile;
    } else if (tile_cache.cache_dir) |cache_dir| {
        file_cached_png_opt = cache_dir.readFileAlloc(std.heap.c_allocator, try png_path(tile_cache.source_url.?, coords.x, coords.y, coords.z), 500000) catch null;
    }

    var dat = try std.heap.c_allocator.alloc(TileData, 1);
    if (file_cached_png_opt) |file_cached_png| {
       dat[0] = .{
           .surface = sdl.IMG_Load_RW(sdl.SDL_RWFromMem(@ptrCast(*c_void, file_cached_png), @intCast(c_int, file_cached_png.len)), 1),
           .transfer_datum = null,
       };
       try tile_cache.map.put(coords, dat[0]);
    } else {
       dat[0] = .{
           .surface = null,
           .transfer_datum = .{
               .client = curl.curl_easy_init().?,
               .coords = coords,
               .data = std.ArrayList(u8).init(std.heap.c_allocator),
               .progress_dl_now = null,
               .progress_dl_total = null,
           },
       };
       try tile_cache.map.put(coords, dat[0]);
       try tile_cache.queue.append(coords);
    }
   return dat[0];
}

fn add_to_curl_multi(tile_cache: *@This(),coords: types.TileSpec) !void {
        var ptr: *TileData = &tile_cache.map.getEntry(coords).?.value;
        std.debug.warn("Going to pass the ptr {*} for coords {}\n", .{ ptr, coords });

        std.debug.warn("FROM {}\n", .{tile_cache.source_url.?});
        var url = try std.heap.c_allocator.alloc(u8, 2000);
        url[199] = 0;
        _ = cstdio.sprintf(&url[0], tile_cache.source_url.?, @intCast(c_int, coords.x), @intCast(c_int, coords.y), @intCast(c_int, coords.z));
        std.debug.warn("Got {}\n", .{url});

        //var url = try std.fmt.allocPrint(std.heap.c_allocator, tile_cache.source_url.?, .{ coords.x, coords.y, coords.z });
        _ = curl.curl_easy_setopt(ptr.transfer_datum.?.client, @intToEnum(curl.CURLoption, curl.CURLOPT_URL), @ptrCast(*c_void, url));
        _ = curl.curl_easy_setopt(ptr.transfer_datum.?.client, @intToEnum(curl.CURLoption, curl.CURLOPT_USERAGENT), "sdlmap/1.0");
        _ = curl.curl_easy_setopt(ptr.transfer_datum.?.client, @intToEnum(curl.CURLoption, curl.CURLOPT_NOPROGRESS), @intCast(c_long, 0));
        _ = curl.curl_easy_setopt(ptr.transfer_datum.?.client, @intToEnum(curl.CURLoption, curl.CURLOPT_XFERINFOFUNCTION), tile_xferinfo_curl_callback);
        _ = curl.curl_easy_setopt(ptr.transfer_datum.?.client, @intToEnum(curl.CURLoption, curl.CURLOPT_XFERINFODATA), ptr);
        _ = curl.curl_easy_setopt(ptr.transfer_datum.?.client, @intToEnum(curl.CURLoption, curl.CURLOPT_WRITEFUNCTION), tile_write_curl_callback);
        _ = curl.curl_easy_setopt(ptr.transfer_datum.?.client, @intToEnum(curl.CURLoption, curl.CURLOPT_WRITEDATA), ptr);
        _ = curl.curl_multi_add_handle(tile_cache.curl_multi, ptr.transfer_datum.?.client);
        std.debug.warn("Add multi handle {}\n", .{coords});
}

pub fn download_loop(tile_cache: *@This()) !void {
    var running: c_int = undefined;
    var n_msgs: c_int = undefined;

    while (true) {
        _ = curl.curl_multi_perform(tile_cache.curl_multi, &running);
        var msg = curl.curl_multi_info_read(tile_cache.curl_multi, &n_msgs);
        while (msg != null) {
            switch (msg.*.msg) {
                .CURLMSG_DONE => {
                    var it = tile_cache.map.iterator();
                    while (it.next()) |kv| {
                        if (kv.value.transfer_datum != null and kv.value.transfer_datum.?.client == msg.*.easy_handle) {

                            if (tile_cache.cache_dir) |cache_dir| {
                              // Save file to tile_cache in fs
                              try cache_dir.writeFile(try png_path(tile_cache.source_url.?, kv.key.x, kv.key.y, kv.key.z), kv.value.transfer_datum.?.data.items);
                            }

                            var surf = sdl.IMG_Load_RW(sdl.SDL_RWFromMem(@ptrCast(*c_void, &kv.value.transfer_datum.?.data.items[0]), @intCast(c_int, kv.value.transfer_datum.?.data.items.len)), 1);
                            _ = curl.curl_multi_remove_handle(tile_cache.curl_multi, kv.value.transfer_datum.?.client);
                            _ = curl.curl_easy_cleanup(kv.value.transfer_datum.?.client);
                            kv.value.surface = surf;// = .{ .surface = surf, .transfer_datum = null };
                            tile_cache.n_current_transfers -= 1;
                            try sdlutil.sdl_push_resize_event();
                            break;
                        }
                    }
                },
                else => {},
            }
            _ = curl.curl_multi_perform(tile_cache.curl_multi, &running);
            msg = curl.curl_multi_info_read(tile_cache.curl_multi, &n_msgs);
        }

        while (tile_cache.queue.items.len > 0 and tile_cache.n_current_transfers < 20) {
          var coords = tile_cache.queue.pop();
          try tile_cache.add_to_curl_multi(coords);
          tile_cache.n_current_transfers += 1;
        }

        sdl.SDL_Delay(50);
    }
}

pub fn download_loop_sdl_threadable(userdata: ?*c_void) callconv(.C) c_int {
    var tile_cache = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata.?));
    var err = tile_cache.download_loop();
    return 0;
}

pub fn set_cache_dir(tile_cache: *@This(), path: [:0]const u8) !void {
  _ = std.fs.cwd().makeDir(path) catch null;
  tile_cache.cache_dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
}

pub fn set_cache_url(tile_cache: *@This(), url: [:0]const u8) !void {
  // Empty Cache
  tile_cache.source_url = url;
  //tile_cache.map.clearAndFree();
  try sdlutil.sdl_push_resize_event();
}

pub fn init() anyerror!@This() {
    if (curl.curl_multi_init()) |curl_multi| {
        var x = @as(@This(), .{
            .source_url = null,
            .cache_dir = null,
            .n_current_transfers = 0,
            .queue = std.ArrayList(types.TileSpec).init(std.heap.c_allocator),
            .map = std.array_hash_map.AutoArrayHashMap(types.TileSpec, TileData).init(std.heap.c_allocator),
            .curl_multi = curl.curl_multi_init().?,
        });
        try x.map.ensureCapacity(2000);
        return x;
    } else {
        return error.MultiInitFail;
    }
}

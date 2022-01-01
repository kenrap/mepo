const std = @import("std");
const sdl = @import("./sdlshim.zig");
const types = @import("./types.zig");
const config = @import("./config.zig");
const errors = @import("./errors.zig");
const TileCache = @import("./TileCache.zig");
const utilconversion = @import("./util/utilconversion.zig");
const utilmepolang = @import("util/utilmepolang.zig");
const utilstrings = @import("util/utilstrings.zig");
const utildbg = @import("util/utildbg.zig");
const utilsdl = @import("util/utilsdl.zig");
const zoom_relative = @import("./api/zoom_relative.zig").zoom_relative;
const FnTable = @import("./api/_FnTable.zig");

var pending_signal: ?u6 = null;
allocator: *std.mem.Allocator,
crosshair_on: bool = true,
crosshair_size: u8 = 10,
debug_message: ?[]const u8 = null,
debug_message_enabled: bool = false,
debug_tiles: bool = false,
debug_vars: bool = false,
distance_unit_tf_km_mi: bool = false,
download_bar: bool = false,
drag: ?struct {
    begin_ticks: u32,
    delta_x: i32 = 0,
    delta_y: i32 = 0,
} = null,
drag_scale: u8 = 1,
fonts: [50]*sdl.TTF_Font,
help: bool = false,
lat: f64 = 0,
lon: f64 = 0,
pin_group_active: u8 = 0,
pin_group_active_item: ?u32 = null,
pin_groups: [10]types.PinGroup = undefined,
renderer: *sdl.SDL_Renderer,
table_clicks: std.array_hash_map.AutoArrayHashMap(types.ClickInput, []const u8),
table_keybindings: std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8),
table_signals: std.array_hash_map.AutoArrayHashMap(u6, []const u8),
tile_cache: *TileCache,
win_h: u32 = config.InitWindowH,
win_w: u32 = config.InitWindowW,
window: *sdl.SDL_Window,
zoom: u8 = 14,

fn blit_crosshair(mepo: *@This()) errors.SDLError!void {
    if (!mepo.crosshair_on) return;

    try utilsdl.sdl_renderer_set_draw_color(mepo.renderer, .{ .value = 0x000000 });
    try utilsdl.errorcheck(sdl.SDL_RenderDrawLine(
        mepo.renderer,
        @intCast(c_int, mepo.win_w / 2 - (mepo.crosshair_size / 2)),
        @intCast(c_int, mepo.win_h / 2),
        @intCast(c_int, mepo.win_w / 2 + (mepo.crosshair_size / 2)),
        @intCast(c_int, mepo.win_h / 2),
    ));
    try utilsdl.errorcheck(sdl.SDL_RenderDrawLine(
        mepo.renderer,
        @intCast(c_int, mepo.win_w / 2),
        @intCast(c_int, mepo.win_h / 2 - (mepo.crosshair_size / 2)),
        @intCast(c_int, mepo.win_w / 2),
        @intCast(c_int, mepo.win_h / 2 + (mepo.crosshair_size / 2)),
    ));
}

pub fn blit_tiles_all(mepo: *@This(), bbox: sdl.SDL_Rect, zoom: u8) !void {
    const vpx = utilconversion.lon_to_px_x(mepo.lon, zoom) - @divTrunc(@intCast(i32, mepo.win_w), 2);
    const vpy = utilconversion.lat_to_px_y(mepo.lat, zoom) - @divTrunc(@intCast(i32, mepo.win_h), 2);
    const begx = vpx - config.Tsize;
    const begy = vpy - config.Tsize;
    const endx = vpx + @intCast(i32, bbox.w) + config.Tsize;
    const endy = vpy + @intCast(i32, bbox.h) + config.Tsize;

    var tilex: i32 = @intCast(i32, @divFloor(begx, config.Tsize));
    var tiley: i32 = @intCast(i32, @divFloor(begy, config.Tsize));

    var x = begx;
    while (x < endx) {
        var y = begy;
        tiley = @intCast(i32, @divFloor(begy, config.Tsize));
        while (y < endy) {
            if (tilex >= 0 and tiley >= 0 and tilex <= std.math.pow(u32, 2, zoom) - 1 and tiley <= std.math.pow(u32, 2, zoom) - 1) {
                try mepo.blit_tile_surface(
                    @intCast(u32, tilex),
                    @intCast(u32, tiley),
                    zoom,
                    vpx,
                    vpy,
                    bbox,
                );
                try mepo.blit_tile_text(@intCast(u32, tilex), @intCast(u32, tiley), zoom, vpx, vpy);
            }
            y += config.Tsize;
            tiley += 1;
        }
        x += config.Tsize;
        tilex += 1;
    }
}

pub fn blit_tile_text(mepo: *@This(), tile_x: u32, tile_y: u32, zoom: u8, x_off: i32, y_off: i32) !void {
    if (!mepo.debug_tiles) return;
    var dl_now: c_long = 0;
    var dl_total: c_long = 0;

    switch (try mepo.tile_cache.tile_ui_retreive_or_queue(.{ .x = tile_x, .y = tile_y, .z = zoom })) {
        .transfer_datum => |transfer_datum| {
            if (transfer_datum.progress_dl_now) |dln| {
                dl_now = dln;
            }
            if (transfer_datum.progress_dl_total) |dlt| {
                dl_total = dlt;
            }
        },
        else => {},
    }

    try mepo.blit_multiline_text(
        0x000000,
        null,
        .{},
        @intCast(i32, tile_x * config.Tsize) - x_off,
        @intCast(i32, tile_y * config.Tsize) - y_off,
        null,
        "tx: {d}\nty: {d}\ndl: {d}/{d}",
        .{ tile_x, tile_y, dl_now, dl_total },
    );
}

pub fn blit_tile_surface(mepo: *@This(), tile_x: u32, tile_y: u32, zoom: u8, x_off: i32, y_off: i32, bbox: sdl.SDL_Rect) !void {
    const rect_dest = sdl.SDL_Rect{
        .x = @intCast(i32, tile_x * config.Tsize) - x_off,
        .y = @intCast(i32, tile_y * config.Tsize) - y_off,
        .w = config.Tsize,
        .h = config.Tsize,
    };

    var rect_intersect: sdl.SDL_Rect = undefined;

    if (@intToEnum(sdl.SDL_bool, sdl.SDL_FALSE) == sdl.SDL_IntersectRect(&rect_dest, &bbox, &rect_intersect)) return;

    const rect_src = sdl.SDL_Rect{
        .x = if (rect_intersect.x > rect_dest.x) rect_dest.w - rect_intersect.w else 0,
        .y = if (rect_intersect.y > rect_dest.y) rect_dest.h - rect_intersect.h else 0,
        .w = rect_intersect.w,
        .h = rect_intersect.h,
    };

    switch (try mepo.tile_cache.tile_ui_retreive_or_queue(.{ .x = tile_x, .y = tile_y, .z = zoom })) {
        .texture => |text| {
            try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, text, &rect_src, &rect_intersect));
        },
        .queued_position => |queued_position| {
            try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xffffff }, rect_intersect, .Fill);
            try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xebebeb }, rect_intersect, .Draw);
            try mepo.blit_multiline_text(
                0x000000,
                null,
                .{ .w = config.Tsize, .h = config.Tsize, .align_x = .Center, .align_y = .Center },
                @intCast(i32, tile_x * config.Tsize) - x_off,
                @intCast(i32, tile_y * config.Tsize) - y_off,
                20,
                "{d}",
                .{queued_position},
            );
        },
        .transfer_datum => {
            try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0x006400 }, rect_intersect, .Fill);
        },
        .error_type => |error_type| {
            try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xffdfd1 }, rect_intersect, .Fill);
            try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xebebeb }, rect_intersect, .Draw);
            try mepo.blit_multiline_text(
                0x000000,
                null,
                .{ .w = config.Tsize, .h = config.Tsize, .align_x = .Center, .align_y = .Center },
                @intCast(i32, tile_x * config.Tsize) - x_off,
                @intCast(i32, tile_y * config.Tsize) - y_off,
                20,
                "Offline",
                .{},
            );
        },
    }
}

fn blit_debug(mepo: *@This()) !void {
    if (mepo.debug_vars) {
        const bbox = mepo.bounding_box();
        const d_unit = if (mepo.distance_unit_tf_km_mi) "km" else "mi";
        try mepo.blit_multiline_text(
            0x000000,
            null,
            .{},
            5,
            5,
            null,
            "x: {d}\ny: {d}\nz: {d}\nlat: {d:.5}\nlon: {d:.5}\nbbox: {d:.3}x{d:.3}{s}",
            .{
                mepo.get_x(),
                mepo.get_y(),
                mepo.zoom,
                mepo.lat,
                mepo.lon,
                utilconversion.distance_haversine(
                    if (mepo.distance_unit_tf_km_mi) .Km else .Mi,
                    mepo.lat,
                    bbox.topleft_lon,
                    mepo.lat,
                    bbox.bottomright_lon,
                ),
                utilconversion.distance_haversine(
                    if (mepo.distance_unit_tf_km_mi) .Km else .Mi,
                    bbox.topleft_lat,
                    mepo.lon,
                    bbox.bottomright_lat,
                    mepo.lon,
                ),
                d_unit,
            },
        );
    }

    if (mepo.debug_message_enabled and mepo.debug_message != null) {
        try mepo.blit_multiline_text(
            0xff0000,
            types.Color{ .value = 0xffffff, .opacity = 200 },
            .{ .align_x = .Right },
            0,
            5,
            null,
            "DEBUG: {s}",
            .{mepo.debug_message.?},
        );
    }
}

fn blit_pins_convert_latlon_to_xy(mepo: *@This(), lat_or_lon: enum { LonToX, LatToY }, lat_lon_value: f64) i32 {
    return switch (lat_or_lon) {
        .LonToX => -1 * (mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), 2) - utilconversion.lon_to_px_x(lat_lon_value, mepo.zoom)),
        .LatToY => -1 * (mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), 2) - utilconversion.lat_to_px_y(lat_lon_value, mepo.zoom)),
    };
}

fn blit_pins(mepo: *@This()) !void {
    var prev_pin: ?*types.Pin = null;

    for (mepo.pin_groups) |pin_group| {
        if (!pin_group.visible) continue;

        for (pin_group.pins.items) |*item, i| {
            defer prev_pin = item;

            const x = mepo.blit_pins_convert_latlon_to_xy(.LonToX, item.lon);
            const y = mepo.blit_pins_convert_latlon_to_xy(.LatToY, item.lat);
            const prev_pin_x = if (prev_pin != null) mepo.blit_pins_convert_latlon_to_xy(.LonToX, prev_pin.?.lon) else undefined;
            const prev_pin_y = if (prev_pin != null) mepo.blit_pins_convert_latlon_to_xy(.LatToY, prev_pin.?.lat) else undefined;

            const size: i32 = 10;
            const color_value: u24 = if (mepo.pin_group_active_item != null and i == mepo.pin_group_active_item.?)
                0xff0000
            else
                mepo.pin_groups[mepo.pin_group_active].color;

            // Optimization to never drawoff-screen pins
            if ((x < 0 or x > mepo.win_w or y < 0 or y > mepo.win_h) and
                (prev_pin == null or (prev_pin_x < 0 or prev_pin_x > mepo.win_w or prev_pin_y < 0 or prev_pin_y > mepo.win_h))) continue;

            // Draw Pin
            if (item.category == .Instructive)
                try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = color_value }, sdl.SDL_Rect{
                    .x = x - @divTrunc(size, 2),
                    .y = y - @divTrunc(size, 2),
                    .w = size,
                    .h = size,
                }, .Fill);

            // Draw connecting line for ordered pin group
            if (mepo.pin_groups[mepo.pin_group_active].ordered and prev_pin != null) {
                try utilsdl.errorcheck(sdl.SDL_RenderDrawLine(
                    mepo.renderer,
                    @intCast(c_int, prev_pin_x),
                    @intCast(c_int, prev_pin_y),
                    @intCast(c_int, x),
                    @intCast(c_int, y),
                ));

                const d_unit = if (mepo.distance_unit_tf_km_mi) "km" else "mi";
                try mepo.blit_multiline_text(
                    0x000000,
                    null,
                    .{},
                    @divFloor(prev_pin_x + x, 2),
                    @divFloor(prev_pin_y + y, 2),
                    null,
                    "{d:.2}{s}",
                    .{
                        utilconversion.distance_haversine(
                            if (mepo.distance_unit_tf_km_mi) .Km else .Mi,
                            prev_pin.?.lat,
                            prev_pin.?.lon,
                            item.lat,
                            item.lon,
                        ),
                        d_unit,
                    },
                );
            }
        }
    }
}

fn blit_pin_active_text(mepo: *@This()) !void {
    if (mepo.pin_group_active_item == null) return;

    const overlay_height = 70;
    const y_off: i32 = if (mepo.download_bar) 20 else 0;
    const y_pos = @intCast(i32, mepo.win_h) - overlay_height - y_off;

    try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xffff00, .opacity = 120 }, sdl.SDL_Rect{
        .x = 0,
        .y = y_pos,
        .w = @intCast(i32, mepo.win_w),
        .h = 200,
    }, .Fill);

    const pin = mepo.pin_groups[mepo.pin_group_active].pins.items[mepo.pin_group_active_item.?];
    const d_unit = if (mepo.distance_unit_tf_km_mi) "km" else "mi";
    try mepo.blit_multiline_text(
        0x000000,
        null,
        .{ .align_y = .Center, .h = overlay_height },
        5,
        y_pos,
        null,
        \\Pin: {s}
        \\Coordinates: {d:.5} lat / {d:.5} lon
        \\Distance: {d:.2}{s} away
    ,
        .{
            pin.name,
            pin.lat,
            pin.lon,
            utilconversion.distance_haversine(
                if (mepo.distance_unit_tf_km_mi) .Km else .Mi,
                mepo.lat,
                mepo.lon,
                pin.lat,
                pin.lon,
            ),
            d_unit,
        },
    );
    try mepo.blit_multiline_text(
        0x000000,
        null,
        .{ .align_y = .Center, .align_x = .Right, .w = mepo.win_w, .h = overlay_height },
        0,
        y_pos,
        null,
        \\{d} of {d}
        \\Group {d}
    ,
        .{
            mepo.pin_group_active_item.? + 1,
            mepo.pin_groups[mepo.pin_group_active].pins.items.len,
            mepo.pin_group_active + 1,
        },
    );
}

fn blit_download_bar(mepo: *@This()) !void {
    if (!mepo.download_bar) return;

    try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xffffff, .opacity = 100 }, sdl.SDL_Rect{
        .x = 0,
        .y = @intCast(i32, mepo.win_h) - 20,
        .w = @intCast(i32, mepo.win_w),
        .h = 200,
    }, .Fill);
    try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0x000000 }, sdl.SDL_Rect{
        .x = 0,
        .y = @intCast(i32, mepo.win_h) - 20,
        .w = @intCast(i32, mepo.win_w),
        .h = 1,
    }, .Fill);
    try mepo.blit_multiline_text(
        0x000000,
        null,
        .{ .align_x = .Right },
        0,
        @intCast(i32, mepo.win_h) - 20 + 3,
        null,
        "Dl: {d:.2}Mb ",
        .{@intToFloat(f32, mepo.tile_cache.byte_counter) / 1024 / 1024},
    );
    const online_offline = if (mepo.tile_cache.thread_download == null) "Offline" else "Online ";
    try mepo.blit_multiline_text(
        0x000000,
        null,
        .{},
        5,
        @intCast(i32, mepo.win_h) - 20 + 3,
        null,
        "{s} / UI Queued: {d} / Bg Queued: {d} / Downloading: {d} / Memory: {d}",
        .{
            online_offline,
            mepo.tile_cache.queue_lifo_ui.count(),
            mepo.tile_cache.queue_lifo_bg.count(),
            mepo.tile_cache.transfer_map.count(),
            mepo.tile_cache.texture_map.count(),
        },
    );
}

fn blit_help(mepo: *@This()) !void {
    if (!mepo.help) return;

    var msg = msg: {
        var acc = std.ArrayList([]const u8).init(mepo.allocator);
        defer acc.deinit();
        defer for (acc.items) |item| mepo.allocator.free(item);

        var it = mepo.table_keybindings.iterator();

        while (it.next()) |kv| {
            const keymod = k: {
                if (@enumToInt(kv.key_ptr.keymod) == sdl.KMOD_LCTRL) {
                    break :k " C";
                } else if (@enumToInt(kv.key_ptr.keymod) == sdl.KMOD_LSHIFT) {
                    break :k " S";
                } else if (@enumToInt(kv.key_ptr.keymod) == sdl.KMOD_LSHIFT | sdl.KMOD_LCTRL) {
                    break :k "CS";
                } else if (@enumToInt(kv.key_ptr.keymod) == sdl.KMOD_LALT) {
                    break :k " A";
                }
                break :k "  ";
            };

            try acc.append(try std.fmt.allocPrint(mepo.allocator, "{s} {s} = {s}", .{ keymod, sdl.SDL_GetKeyName(@enumToInt(kv.key_ptr.keycode)), kv.value_ptr.* }));
        }

        break :msg try std.mem.join(mepo.allocator, "\n", acc.items);
    };
    defer mepo.allocator.free(msg);

    try mepo.blit_multiline_text(
        0x000000,
        types.Color{ .value = 0xe8e8e8, .opacity = 120 },
        .{ .align_x = .Center, .align_y = .Center },
        0,
        0,
        null,
        \\mepo - Development version (0.2)
        \\ 
        \\Keybindings:
        \\{s}
    ,
        .{msg},
    );
}

pub fn blit(mepo: *@This()) !void {
    try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xffffff }, null, .Fill);
    try mepo.blit_tiles_all(
        .{
            .x = 0,
            .y = 0,
            .w = @intCast(c_int, mepo.win_w),
            .h = @intCast(c_int, mepo.win_h),
        },
        mepo.zoom,
    );
    try mepo.blit_debug();
    try mepo.blit_pins();
    try mepo.blit_pin_active_text();
    try mepo.blit_crosshair();
    try mepo.blit_download_bar();
    try mepo.blit_help();

    sdl.SDL_RenderPresent(mepo.renderer);

    // Update title
    const title = try std.fmt.allocPrintZ(mepo.allocator, "mepo - {d:.5} lat, {d:.5} lon", .{ mepo.lat, mepo.lon });
    defer mepo.allocator.free(title);
    _ = sdl.SDL_SetWindowTitle(mepo.window, title);
}

fn event_multigesture(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    const threshold = 0.005;
    if (e.mgesture.dDist > threshold) {
        zoom_relative(mepo, 1);
        return .Redraw;
    }
    if (e.mgesture.dDist < -threshold) {
        zoom_relative(mepo, -1);
        return .Redraw;
    }
    return .None;
}

fn event_mousebuttondown(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (!mepo.within_touch_bounds(e.button.x, e.button.y)) {
        mepo.drag = null;
        return .None;
    } else if (e.button.button == sdl.SDL_BUTTON_LEFT) {
        mepo.drag = .{ .begin_ticks = sdl.SDL_GetTicks() };
    }
    return .None;
}

fn event_mousebuttonup(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (!mepo.within_touch_bounds(e.button.x, e.button.y)) {
        mepo.drag = null;
        return .None;
    }

    mepo.drag = null;

    const key = .{
        .button = e.button.button,
        .clicks = @intCast(i8, e.button.clicks),
    };
    if (mepo.table_clicks.get(key)) |run_expression| {
        utildbg.log("Got click table function {s} for {}\n", .{ run_expression, key });
        mepo.mepolang_execute(run_expression) catch unreachable;
    }
    return .Redraw;
}

fn event_mousemotion(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.drag != null and mepo.within_touch_bounds(e.motion.x, e.motion.y)) {
        mepo.drag.?.delta_x += std.math.absInt(e.motion.xrel) catch unreachable;
        mepo.drag.?.delta_y += std.math.absInt(e.motion.yrel) catch unreachable;
        mepo.set_x(mepo.get_x() - (e.motion.xrel * mepo.drag_scale));
        mepo.set_y(mepo.get_y() - (e.motion.yrel * mepo.drag_scale));
        return .Drag;
    } else {
        mepo.drag = null;
    }
    return .None;
}

fn within_touch_bounds(mepo: *@This(), x: c_int, y: c_int) bool {
    return x > 0 and y > 0 and x < mepo.win_w and y < mepo.win_h;
}

fn event_mousewheel(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    zoom_relative(mepo, e.wheel.y);
    return .Redraw;
}

fn event_keydown(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.table_keybindings.get(.{
        .keycode = @intToEnum(sdl.SDL_KeyCode, @intCast(c_int, e.key.keysym.sym)),
        .keymod = @intToEnum(sdl.SDL_Keymod, @intCast(c_int, e.key.keysym.mod)),
    })) |run_expression| {
        utildbg.log("Got keybindings table function with run expression: <{s}>\n", .{run_expression});
        mepo.mepolang_execute(run_expression) catch unreachable;
        return .Redraw;
    }
    return .None;
}

fn event_signal(mepo: *@This(), signal: u6) types.Pending {
    if (mepo.table_signals.get(signal)) |run_expression| {
        utildbg.log("Got signals table function {s}\n", .{run_expression});
        mepo.mepolang_execute(run_expression) catch unreachable;
        return .Redraw;
    }
    return .None;
}

fn event_windowevent(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    switch (@intToEnum(sdl.SDL_WindowEventID, e.window.event)) {
        .SDL_WINDOWEVENT_RESIZED => {
            mepo.win_w = @intCast(u32, e.window.data1);
            mepo.win_h = @intCast(u32, e.window.data2);
            //mepo.center_on_coords(old_lat, old_lon);
        },
        else => {},
    }
    return .Redraw;
}

fn event_quit(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    graceful_terminate();
    return .None;
}

fn event_unhandled(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    utildbg.log("Unhandled SDL Event: {}\n", .{e.type});
    return .None;
}

pub fn mepolang_execute(mepo: *@This(), mepolang_text: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    for (try utilstrings.statementize(&arena.allocator, try utilstrings.tokenize(&arena.allocator, mepolang_text))) |statement| {
        utildbg.log("Executing statment: {s}\n", .{statement});
        if (statement.len < 1) continue;

        // Lookup and run fn
        if (FnTable.get(statement[0])) |func| {
            const args: [types.MepoFnNargs]types.MepoArg = try utilmepolang.mepolang_argize(&arena.allocator, statement[1..statement.len]);
            utildbg.log("Running API function for: {s} requested by mepolang input statement: {s}\n", .{ statement[0], statement });
            func(mepo, args) catch |mepolang_err| {
                utildbg.log("Error running API function for: {s}: {}\n", .{ statement[0], mepolang_err });
            };
        } else if (statement[0].len == 1 and statement[0][0] == '#') {
            // Comment nop
        } else {
            utildbg.log("Requested API function {s} but that's not registered in ftable\n", .{statement[0]});
        }
    }
}

fn click_hold_check_dispatch(mepo: *@This()) void {
    if (mepo.drag == null) return;

    const threshold_hit_hold_ms = sdl.SDL_GetTicks() >= mepo.drag.?.begin_ticks + config.DragThresholdTicks;
    const threshold_hit_distance = mepo.drag.?.delta_x + mepo.drag.?.delta_y <= config.DragThresholdDelta;

    if (threshold_hit_hold_ms and threshold_hit_distance) {
        mepo.drag = null;
        // TODO: hold support for right click as well?
        if (mepo.table_clicks.get(.{ .button = sdl.SDL_BUTTON_LEFT, .clicks = -1 })) |run_expression| {
            utildbg.log("Got hold table function {s} after dispatch time\n", .{run_expression});
            mepo.mepolang_execute(run_expression) catch unreachable;
            utilsdl.sdl_push_resize_event();
        }
    }
}

pub fn sdl_event_loop(mepo: *@This()) !void {
    var pending: types.Pending = .None;
    var e: sdl.SDL_Event = undefined;

    while (true) {
        // Redraw
        const has_pending_motion_events = (sdl.SDL_bool.SDL_TRUE == sdl.SDL_HasEvent(@enumToInt(sdl.SDL_EventType.SDL_MOUSEMOTION)));
        if ((!has_pending_motion_events and pending == .Drag) or pending == .Redraw) {
            try blit(mepo);
        }

        mepo.click_hold_check_dispatch();

        // Process SDL events
        if (sdl.SDL_WaitEventTimeout(&e, config.DragThresholdTicks) > 0) {
            pending = switch (@intToEnum(sdl.SDL_EventType, @intCast(c_int, e.type))) {
                .SDL_KEYDOWN => event_keydown,
                .SDL_MOUSEBUTTONDOWN => event_mousebuttondown,
                .SDL_MOUSEMOTION => event_mousemotion,
                .SDL_MOUSEBUTTONUP => event_mousebuttonup,
                .SDL_MOUSEWHEEL => event_mousewheel,
                .SDL_MULTIGESTURE => event_multigesture,
                .SDL_QUIT => event_quit,
                .SDL_WINDOWEVENT => event_windowevent,
                else => event_unhandled,
            }(mepo, e);
        }

        // Process user signals
        if (pending_signal) |sig| {
            pending = mepo.event_signal(sig);
            pending_signal = null;
        }
    }
}

pub fn blit_multiline_text(
    mepo: *@This(),
    color: u24,
    background_opt: ?types.Color,
    alignment: types.BoxAlignment,
    x: i32,
    y: i32,
    font_size_opt: ?u32,
    comptime fmt_string: [:0]const u8,
    args: anytype,
) !void {
    var msg = try std.fmt.allocPrintZ(mepo.allocator, fmt_string, args);
    defer mepo.allocator.free(msg);

    const font_size = font_size: {
        if (font_size_opt) |font_size| {
            if (font_size > mepo.fonts.len) return error.FontTooBig else break :font_size font_size;
        } else {
            break :font_size config.FontSize;
        }
    };

    var textures_width: c_int = 0;
    var textures_height: c_int = 0;

    // Accumulate lines rendered into slice of textures
    var textures: []*sdl.SDL_Texture = textures: {
        var textures_array: [50]*sdl.SDL_Texture = undefined;
        var textures_array_size: usize = 0;

        var lines_it = std.mem.tokenize(msg, "\n");
        while (lines_it.next()) |line| {
            if (textures_array_size + 1 > textures_array.len - 1) break;

            const line_sentinel_terminated = try std.mem.dupeZ(mepo.allocator, u8, line);
            defer mepo.allocator.free(line_sentinel_terminated);

            const text_surf = try utilsdl.errorcheck_ptr(
                sdl.SDL_Surface,
                sdl.TTF_RenderText_Blended(mepo.fonts[font_size], @ptrCast([*c]const u8, line_sentinel_terminated), (types.Color{ .value = color }).sdl()),
            );
            defer sdl.SDL_FreeSurface(text_surf);

            const text = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTextureFromSurface(mepo.renderer, text_surf));
            textures_height += text_surf.h;
            textures_width = std.math.max(textures_width, text_surf.w);
            textures_array[textures_array_size] = text;
            textures_array_size += 1;
        }

        break :textures textures_array[0..textures_array_size];
    };

    // Rendering
    {
        // Calculate X/Y offsets
        const x_off: c_int = x_off: {
            const bbox_total_w = @intCast(c_int, if (alignment.w) |w| w else mepo.win_w);
            const offset = switch (alignment.align_x) {
                .Left => 0,
                .Right => bbox_total_w - textures_width,
                .Center => @divTrunc(bbox_total_w - textures_width, 2),
            };
            break :x_off x + offset;
        };
        var y_off: c_int = y_off: {
            const bbox_total_h = @intCast(c_int, if (alignment.h) |h| h else mepo.win_h);
            const offset = switch (alignment.align_y) {
                .Top => 0,
                .Bottom => bbox_total_h - textures_height,
                .Center => @divTrunc(bbox_total_h - textures_height, 2),
            };
            break :y_off y + offset;
        };

        // Render background
        if (background_opt) |background|
            try utilsdl.sdl_renderer_rect(mepo.renderer, background, sdl.SDL_Rect{ .x = x_off, .y = y_off, .w = textures_width, .h = textures_height }, .Fill);

        // Reder text
        for (textures) |texture| {
            defer sdl.SDL_DestroyTexture(texture);
            var dest_rect = sdl.SDL_Rect{
                .x = x_off,
                .y = y_off,
                .w = undefined,
                .h = undefined,
            };
            try utilsdl.errorcheck(sdl.SDL_QueryTexture(texture, null, null, &dest_rect.w, &dest_rect.h));
            y_off += dest_rect.h;
            try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, texture, null, &dest_rect));
        }
    }
}

pub fn update_debug_message(mepo: *@This(), new_msg_opt: ?[]const u8) !void {
    if (mepo.debug_message) |dbg_msg| mepo.allocator.free(dbg_msg);
    if (new_msg_opt) |new_msg| {
        mepo.debug_message = try mepo.allocator.dupe(u8, new_msg);
    } else {
        mepo.debug_message = null;
    }
    utilsdl.sdl_push_resize_event();
}

pub fn get_x(mepo: *@This()) i32 {
    return utilconversion.lon_to_px_x(mepo.lon, mepo.zoom);
}

pub fn get_y(mepo: *@This()) i32 {
    return utilconversion.lat_to_px_y(mepo.lat, mepo.zoom);
}

pub fn set_x(mepo: *@This(), x: i32) void {
    mepo.lon = utilconversion.px_x_to_lon(x, mepo.zoom);
}

pub fn set_y(mepo: *@This(), y: i32) void {
    mepo.lat = utilconversion.px_y_to_lat(y, mepo.zoom);
}

pub fn bounding_box(mepo: *@This()) types.LatLonBox {
    return .{
        .topleft_lat = utilconversion.px_y_to_lat(mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), @intCast(i32, 2)), mepo.zoom),
        .topleft_lon = utilconversion.px_x_to_lon(mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), @intCast(i32, 2)), mepo.zoom),
        .bottomright_lat = utilconversion.px_y_to_lat(mepo.get_y() + @divTrunc(@intCast(i32, mepo.win_h), @intCast(i32, 2)), mepo.zoom),
        .bottomright_lon = utilconversion.px_x_to_lon(mepo.get_x() + @divTrunc(@intCast(i32, mepo.win_w), @intCast(i32, 2)), mepo.zoom),
    };
}

pub fn graceful_terminate() void {
    utildbg.log("Graceful shutdown\n", .{});
    sdl.SDL_VideoQuit();
    sdl.SDL_Quit();
    std.os.exit(0);
}

pub fn sighandle_terminate(arg: c_int) callconv(.C) void {
    utildbg.log("Graceful shutdown via signal: {}", .{arg});
    graceful_terminate();
}

pub fn sighandle_user(arg: c_int) callconv(.C) void {
    utildbg.log("User signal: {}\n", .{arg});
    pending_signal = @truncate(u6, @bitCast(c_uint, arg));
}

pub fn init(allocator: *std.mem.Allocator, tile_cache: *TileCache, cfg_opt: ?[]const u8) anyerror!@This() {
    // Initialize video, create window
    const window = window: {
        try utilsdl.errorcheck(sdl.SDL_Init(sdl.SDL_INIT_VIDEO));
        const w = try utilsdl.errorcheck_ptr(sdl.SDL_Window, sdl.SDL_CreateWindow(
            "mepo",
            config.InitWindowX,
            config.InitWindowY,
            config.InitWindowW,
            config.InitWindowH,
            sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE,
        ));
        sdl.SDL_SetWindowPosition(w, config.InitWindowX, config.InitWindowY);
        break :window w;
    };

    // Create struct
    var instance = @as(@This(), .{
        .allocator = allocator,
        .fonts = fonts: {
            // Initialize TTF, load fonts
            try utilsdl.errorcheck(sdl.TTF_Init());

            const font_dat = @embedFile("../assets/inconsolata.ttf");
            var fonts: [50]*sdl.TTF_Font = undefined;
            var font_size: usize = 0;
            while (font_size < fonts.len) : (font_size += 1) {
                fonts[font_size] = try utilsdl.errorcheck_ptr(
                    sdl.TTF_Font,
                    sdl.TTF_OpenFontRW(
                        sdl.SDL_RWFromConstMem(@ptrCast(*const c_void, &font_dat[0]), font_dat.len),
                        1,
                        @intCast(c_int, font_size),
                    ),
                );
            }
            break :fonts fonts;
        },
        .renderer = try utilsdl.errorcheck_ptr(sdl.SDL_Renderer, sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_SOFTWARE)),
        .table_keybindings = std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8).init(allocator),
        .table_clicks = std.array_hash_map.AutoArrayHashMap(types.ClickInput, []const u8).init(allocator),
        .table_signals = std.array_hash_map.AutoArrayHashMap(u6, []const u8).init(allocator),
        .tile_cache = tile_cache,
        .window = window,
    });

    // Set renderer for tile cache
    tile_cache.renderer = instance.renderer;

    // Initialize pin groups
    for (instance.pin_groups) |*g| {
        g.ordered = true;
        g.pins = std.ArrayList(types.Pin).init(allocator);
    }

    // Run config (base and then user provided STDIN)
    {
        try instance.mepolang_execute(config.DefaultBaseConfig);
        if (cfg_opt) |cfg| try instance.mepolang_execute(cfg);
    }

    // Setup TERM/INT signals
    {
        const sigs: [2]u6 = .{ std.os.linux.SIGTERM, std.os.linux.SIGINT };
        for (sigs) |sig| {
            if (0 != std.os.linux.sigaction(sig, &.{
                .handler = .{ .handler = sighandle_terminate },
                .mask = [_]u32{0} ** 32,
                .flags = @as(c_uint, 0),
            }, null)) {
                return error.FailedToSetupSighandler;
            }
        }
    }

    return instance;
}

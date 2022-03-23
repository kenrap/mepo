const std = @import("std");
const sdl = @import("./sdlshim.zig");
const types = @import("./types.zig");
const config = @import("./config.zig");
const errors = @import("./errors.zig");
const TileCache = @import("./TileCache.zig");
const utilconversion = @import("./util/utilconversion.zig");
const utilmepolang = @import("util/utilmepolang.zig");
const utilplatform = @import("util/utilplatform.zig");
const utildbg = @import("util/utildbg.zig");
const utilsdl = @import("util/utilsdl.zig");
const zoom_relative = @import("./api/zoom_relative.zig").zoom_relative;
const FnTable = @import("./api/_FnTable.zig");

var pending_signal: ?u6 = null;
allocator: std.mem.Allocator,
crosshair_on: bool = true,
crosshair_size: u8 = 10,
debug_message: ?[]const u8 = null,
debug_message_enabled: bool = false,
debug_tiles: bool = false,
distance_unit_tf_km_mi: bool = false,
drag: ?struct {
    begin_ticks: u32,
    point: sdl.SDL_Point,
    delta_x: i32 = 0,
    delta_y: i32 = 0,
} = null,
fingers: std.ArrayList(sdl.SDL_FingerID),
fingers_gesture_delta: isize = 0,
drag_scale: u8 = 1,
fonts_normal: [50]*sdl.TTF_Font,
fonts_bold: [50]*sdl.TTF_Font,
fontsize_ui: u8 = 20,
help: bool = false,
lat: f64 = 0,
lon: f64 = 0,
overlay_debugbar: bool = true,
overlay_pindetails: bool = true,
pin_group_active: u8 = 0,
pin_group_active_item: ?u32 = null,
pin_groups: [10]types.PinGroup = undefined,
renderer: *sdl.SDL_Renderer,
table_gestures: std.array_hash_map.AutoArrayHashMap(types.GestureInput, []const u8),
table_clicks: std.array_hash_map.AutoArrayHashMap(types.ClickInput, []const u8),
table_keybindings: std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8),
table_signals: std.array_hash_map.AutoArrayHashMap(u6, []const u8),
tile_cache: *TileCache,
title_update_ms: usize = 0,
uibuttons: std.ArrayList(types.UIButton),
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

    if (sdl.SDL_IntersectRect(&rect_dest, &bbox, &rect_intersect) == sdl.SDL_FALSE) return;

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
        .error_type => {
            try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xffdfd1 }, rect_intersect, .Fill);
            try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xebebeb }, rect_intersect, .Draw);
            try mepo.blit_multiline_text(
                0x000000,
                null,
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

fn blit_overlay_pindetails(mepo: *@This()) !void {
    if (!mepo.overlay_pindetails) return;

    const d_unit = if (mepo.distance_unit_tf_km_mi) "km" else "mi";

    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    var al = std.ArrayList([2][:0]const u8).init(arena.allocator());
    if (mepo.pin_group_active_item) |_| {
        const pin = mepo.pin_groups[mepo.pin_group_active].pins.items[mepo.pin_group_active_item.?];
        const pin_coords_str = try std.fmt.allocPrintZ(arena.allocator(), "{d:.5} lat / {d:.5} lon", .{ pin.lat, pin.lon });
        const distance_str = try std.fmt.allocPrintZ(arena.allocator(), "{d:.2}{s} away", .{
            utilconversion.distance_haversine(
                if (mepo.distance_unit_tf_km_mi) .Km else .Mi,
                mepo.lat,
                mepo.lon,
                pin.lat,
                pin.lon,
            ),
            d_unit,
        });

        try al.append(([_][:0]const u8{ "Pin:", pin.name })[0..].*);
        if (pin.handle != null) {
            try al.append(([_][:0]const u8{ "Handle:", pin.handle.? })[0..].*);
        }
        try al.append(([_][:0]const u8{ "Coords:", pin_coords_str })[0..].*);
        try al.append(([_][:0]const u8{ try std.fmt.allocPrintZ(
            arena.allocator(),
            "Group {d}:",
            .{mepo.pin_group_active + 1},
        ), try std.fmt.allocPrintZ(
            arena.allocator(),
            "{d} of {d} ",
            .{
                mepo.pin_group_active_item.? + 1,
                mepo.pin_groups[mepo.pin_group_active].pins.items.len,
            },
        ) })[0..].*);
        try al.append(([_][:0]const u8{ "Dist:", distance_str })[0..].*);
        for (pin.metadata.keys()) |k| {
            const duped = try std.fmt.allocPrintZ(arena.allocator(), "{s}", .{k});
            try al.append(([_][:0]const u8{ duped, pin.metadata.get(k).? })[0..].*);
        }
        try mepo.blit_table(5, 5, 5, al.items);
    }
}

fn blit_debugmessage(mepo: *@This()) !void {
    if (mepo.debug_message_enabled and mepo.debug_message != null) {
        const bottom_off: u32 = if (mepo.overlay_debugbar) mepo.fontsize_ui + 10 else 5;
        try mepo.blit_multiline_text(
            0xff0000,
            null,
            types.Color{ .value = 0xffffff, .opacity = 200 },
            .{ .h = mepo.win_h - bottom_off, .align_x = .Left, .align_y = .Bottom },
            0,
            5,
            null,
            "DEBUG: {s}",
            .{mepo.debug_message.?},
        );
    }
}

fn blit_pin(mepo: *@This(), pin: types.Pin, prev_pin: ?types.Pin, pin_group: u8, pin_color: types.Color, pin_label_bg: types.Color) !void {
    const size: i32 = 10;
    const x = mepo.convert_latlon_to_xy(.LonToX, pin.lon);
    const y = mepo.convert_latlon_to_xy(.LatToY, pin.lat);
    const prev_pin_x = if (prev_pin != null) mepo.convert_latlon_to_xy(.LonToX, prev_pin.?.lon) else undefined;
    const prev_pin_y = if (prev_pin != null) mepo.convert_latlon_to_xy(.LatToY, prev_pin.?.lat) else undefined;

    // Optimization to never drawoff-screen pins
    if ((x < 0 or x > mepo.win_w or y < 0 or y > mepo.win_h) and
        (prev_pin == null or (prev_pin_x < 0 or prev_pin_x > mepo.win_w or prev_pin_y < 0 or prev_pin_y > mepo.win_h))) return;

    // Draw Pin
    if (pin.category == .Instructive)
        try utilsdl.sdl_renderer_rect(mepo.renderer, pin_color, sdl.SDL_Rect{
            .x = x - @divTrunc(size, 2),
            .y = y - @divTrunc(size, 2),
            .w = size,
            .h = size,
        }, .Fill);

    // Draw Pin label for current pin group
    if (pin.category == .Instructive and mepo.pin_group_active == pin_group) {
        const pin_label_border = .{ .value = 0xe8e8e8, .opacity = 255 };
        try mepo.blit_multiline_text(
            0x000000,
            pin_label_border,
            pin_label_bg,
            .{},
            x,
            y,
            config.ZoomLevelToPinFontSize[mepo.zoom],
            "{s}",
            .{pin.name},
        );
    }

    // Draw connecting line for ordered pin group
    if (mepo.pin_groups[pin_group].ordered and prev_pin != null) {
        try utilsdl.errorcheck(sdl.aalineColor(
            mepo.renderer,
            @intCast(i16, prev_pin_x),
            @intCast(i16, prev_pin_y),
            @intCast(i16, x),
            @intCast(i16, y),
            pin_color.to_u32(),
        ));
    }
}

fn blit_pins(mepo: *@This()) !void {
    for (mepo.pin_groups) |pin_group, pin_group_i| {
        var ordered_group_active_path = false;
        if (!pin_group.visible) continue;
        var prev_pin: ?*types.Pin = null;
        for (pin_group.pins.items) |*pin, pin_i| {
            defer prev_pin = pin;

            const color = if (pin_group_i == mepo.pin_group_active and mepo.pin_group_active_item != null and
                ((mepo.pin_groups[pin_group_i].ordered and ordered_group_active_path) or
                (!mepo.pin_groups[pin_group_i].ordered and mepo.pin_group_active_item.? == pin_i))) 0xff0000 else pin_group.color;

            // E.g. ordered_group_active_path just tracks every time
            // an instructive pin is hit so subsequent structural pins
            // highlighted in "active"/red color until next structural pin
            // hit and full "path" of the active segment of an ordered pin
            // group shows continuously as the active color
            if (mepo.pin_group_active_item != null and mepo.pin_groups[pin_group_i].pins.items[pin_i].category == .Instructive)
                ordered_group_active_path = mepo.pin_group_active_item.? == pin_i;

            try mepo.blit_pin(
                pin.*,
                if (prev_pin != null) prev_pin.?.* else null,
                @intCast(u8, pin_group_i),
                .{ .value = color },
                .{ .value = 0xffffff, .opacity = 100 },
            );
        }
    }

    if (mepo.pin_group_active_item) |active_pin_i| {
        try mepo.blit_pin(
            mepo.pin_groups[mepo.pin_group_active].pins.items[active_pin_i],
            null,
            mepo.pin_group_active,
            .{ .value = 0xff0000 },
            .{ .value = 0xffffff, .opacity = 255 },
        );
    }
}

fn blit_overlay_debugbar(mepo: *@This()) !void {
    if (!mepo.overlay_debugbar) return;
    const bottombar_height = mepo.fontsize_ui + 5;

    const bg: types.Color = color: {
        if (mepo.tile_cache.thread_download == null) {
            break :color .{ .value = 0xffdfd1, .opacity = 255 };
        } else if (mepo.tile_cache.queue_lifo_ui.count() > 0) {
            break :color .{ .value = 0xd7ffd6, .opacity = 255 };
        } else if (mepo.tile_cache.queue_lifo_bg.count() > 0) {
            break :color .{ .value = 0xc7d4ff, .opacity = 255 };
        } else {
            break :color .{ .value = 0xffffff, .opacity = 100 };
        }
    };

    try utilsdl.sdl_renderer_rect(mepo.renderer, bg, sdl.SDL_Rect{
        .x = 0,
        .y = @intCast(i32, mepo.win_h) - bottombar_height,
        .w = @intCast(i32, mepo.win_w),
        .h = 200,
    }, .Fill);
    try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0x000000 }, sdl.SDL_Rect{
        .x = 0,
        .y = @intCast(i32, mepo.win_h) - bottombar_height,
        .w = @intCast(i32, mepo.win_w),
        .h = 1,
    }, .Fill);
    try mepo.blit_multiline_text(
        0x000000,
        null,
        null,
        .{ .align_x = .Right },
        0,
        @intCast(i32, mepo.win_h) - bottombar_height + 3,
        null,
        "Dl: {d:.2}Mb ",
        .{@intToFloat(f32, mepo.tile_cache.byte_counter) / 1024 / 1024},
    );
    try mepo.blit_multiline_text(
        0x000000,
        null,
        null,
        .{},
        5,
        @intCast(i32, mepo.win_h) - bottombar_height + 3,
        null,
        "{d:.3} {d:.3} O:{d}, Q:{d}, B:{d}, D:{d}, M:{d}",
        .{
            mepo.lat,
            mepo.lon,
            @boolToInt(mepo.tile_cache.thread_download != null),
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
            const keymod = switch (kv.key_ptr.keymod) {
                sdl.KMOD_LCTRL | sdl.KMOD_RCTRL => " C",
                sdl.KMOD_LSHIFT | sdl.KMOD_RSHIFT => " S",
                sdl.KMOD_LSHIFT | sdl.KMOD_RSHIFT | sdl.KMOD_LCTRL | sdl.KMOD_RCTRL => "CS",
                sdl.KMOD_LALT | sdl.KMOD_RALT => " A",
                else => "  ",
            };

            try acc.append(try std.fmt.allocPrint(mepo.allocator, "{s} {c} = {s}", .{ keymod, kv.key_ptr.key, kv.value_ptr.* }));
        }

        break :msg try std.mem.join(mepo.allocator, "\n", acc.items);
    };
    defer mepo.allocator.free(msg);

    try mepo.blit_multiline_text(
        0x000000,
        null,
        types.Color{ .value = 0xe8e8e8, .opacity = 120 },
        .{ .align_x = .Center, .align_y = .Center },
        0,
        0,
        null,
        \\mepo - Development version (0.4)
        \\ 
        \\Keybindings:
        \\{s}
    ,
        .{msg},
    );
}

fn blit_uibuttons(mepo: *@This(), determine_click_target: ?sdl.SDL_MouseButtonEvent) !?types.UIButton {
    var btn_i = mepo.uibuttons.items.len;
    const pad: c_int = 5;
    var right_pad: c_int = 10;
    const pad_bottom: c_int = mepo.fontsize_ui + 10;

    while (btn_i > 0) {
        btn_i -= 1;

        if (mepo.uibuttons.items[btn_i].only_visible_when_has_pins and mepo.pin_groups[mepo.pin_group_active].pins.items.len == 0)
            continue;

        const surf = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderText_Blended(mepo.fonts_bold[mepo.fontsize_ui], @ptrCast([*c]const u8, mepo.uibuttons.items[btn_i].text), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        defer sdl.SDL_FreeSurface(surf);

        const bg_w = surf.w + pad * 2;
        const bg_h = surf.h + pad * 2;
        defer right_pad += bg_w;

        const target = sdl.SDL_Rect{
            .x = @intCast(c_int, mepo.win_w) - right_pad - bg_w,
            .y = @intCast(c_int, mepo.win_h) - bg_h - pad_bottom,
            .w = bg_w + 1,
            .h = bg_h + 1,
        };

        if (determine_click_target) |want_target| {
            // Determine if click fell within btn
            if (want_target.x >= target.x and want_target.y >= target.y and want_target.x <= target.x + target.w and want_target.y <= target.y + target.h)
                return mepo.uibuttons.items[btn_i];
        } else {
            // Rendering
            const dest_rect_lab = sdl.SDL_Rect{
                .x = target.x + pad,
                .y = target.y + pad,
                .w = surf.w,
                .h = surf.h,
            };

            const bg_color = bg_color: {
                if (mepo.drag != null and sdl.SDL_TRUE == sdl.SDL_PointInRect(&mepo.drag.?.point, &dest_rect_lab)) {
                    break :bg_color types.Color{ .value = 0xe8e8e8, .opacity = 255 };
                } else {
                    break :bg_color types.Color{ .value = 0xffffff, .opacity = 125 };
                }
            };

            try utilsdl.sdl_renderer_rect(mepo.renderer, bg_color, target, .Fill);
            try utilsdl.sdl_renderer_rect(mepo.renderer, types.Color{ .value = 0x888888, .opacity = 255 }, target, .Draw);
            const text = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTextureFromSurface(mepo.renderer, surf));
            defer sdl.SDL_DestroyTexture(text);
            try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, text, null, &dest_rect_lab));
        }
    }

    return null;
}

pub fn blit(mepo: *@This()) !void {
    try utilsdl.errorcheck(sdl.SDL_RenderClear(mepo.renderer));
    try utilsdl.sdl_renderer_rect(
        mepo.renderer,
        .{ .value = 0xffffff },
        .{ .x = 0, .y = 0, .w = @intCast(c_int, mepo.win_w), .h = @intCast(c_int, mepo.win_h) },
        .Fill,
    );
    try mepo.blit_tiles_all(
        .{
            .x = 0,
            .y = 0,
            .w = @intCast(c_int, mepo.win_w),
            .h = @intCast(c_int, mepo.win_h),
        },
        mepo.zoom,
    );
    try mepo.blit_pins();
    try mepo.blit_crosshair();
    try mepo.blit_overlay_pindetails();
    try mepo.blit_overlay_debugbar();
    try mepo.blit_help();
    try mepo.blit_debugmessage();
    _ = try mepo.blit_uibuttons(null);

    sdl.SDL_RenderPresent(mepo.renderer);

    // Update title, this is actually a relatively slow operation on certain
    // platforms such as Wayland/Phosh; thus we only update at a certain
    // specified config frequency
    if (sdl.SDL_GetTicks() > mepo.title_update_ms + config.TitleUpdateFrequencyMs) {
        mepo.title_update_ms = sdl.SDL_GetTicks();
        const title = try std.fmt.allocPrintZ(mepo.allocator, "mepo - {d:.5} lat, {d:.5} lon", .{ mepo.lat, mepo.lon });
        defer mepo.allocator.free(title);
        _ = sdl.SDL_SetWindowTitle(mepo.window, title);
    }
}

pub fn convert_latlon_to_xy(mepo: *@This(), lat_or_lon: enum { LonToX, LatToY }, lat_lon_value: f64) i32 {
    return switch (lat_or_lon) {
        .LonToX => -1 * (mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), 2) - utilconversion.lon_to_px_x(lat_lon_value, mepo.zoom)),
        .LatToY => -1 * (mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), 2) - utilconversion.lat_to_px_y(lat_lon_value, mepo.zoom)),
    };
}

fn event_fingerdown(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    for (mepo.fingers.items) |f| if (e.tfinger.fingerId == f) return .None;
    mepo.fingers.append(e.tfinger.fingerId) catch unreachable;
    if (mepo.fingers.items.len > 1) mepo.fingers_gesture_delta = 0;
    return .None;
}

fn event_fingerup(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    for (mepo.fingers.items) |f, i| {
        if (e.tfinger.fingerId == f) {
            _ = mepo.fingers.orderedRemove(i);
            break;
        }
    }
    if (mepo.fingers.items.len == 2) mepo.fingers_gesture_delta = 0;
    return .None;
}

fn event_textinput(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    var idx: usize = 0;
    var pending: types.Pending = .None;
    const text = e.text.text;
    while (text[idx] != 0) : (idx += 1) {
        const char_z: [2]u8 = .{ std.ascii.toLower(text[idx]), 0 };
        const key = types.KeyInput{
            .keymod = if (std.ascii.isUpper(text[idx])) sdl.KMOD_LSHIFT | sdl.KMOD_RSHIFT else 0,
            .key = char_z[0],
        };
        if (mepo.table_keybindings.get(key)) |run_expression| {
            utildbg.log("Got keybindings table function via textinput with run expression: <{s}>\n", .{run_expression});
            mepo.mepolang_execute(run_expression) catch unreachable;
            pending = .Redraw;
        }
    }
    return pending;
}

fn event_multigesture(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    const threshold_pan_dist = 0.004;
    const threshold_rotate_radians = 0.015;

    const delta_max = 2;
    const run_gesture_opt: ?types.GestureInput = run_gesture: {
        if (e.mgesture.dDist > threshold_pan_dist) {
            break :run_gesture .{ .action = .Pan, .direction = .In, .n_fingers = @intCast(u8, mepo.fingers.items.len) };
        } else if (e.mgesture.dDist < -threshold_pan_dist) {
            break :run_gesture .{ .action = .Pan, .direction = .Out, .n_fingers = @intCast(u8, mepo.fingers.items.len) };
        } else if (e.mgesture.dTheta > threshold_rotate_radians) {
            break :run_gesture .{ .action = .Rotate, .direction = .In, .n_fingers = @intCast(u8, mepo.fingers.items.len) };
        } else if (e.mgesture.dTheta < -threshold_rotate_radians) {
            break :run_gesture .{ .action = .Rotate, .direction = .Out, .n_fingers = @intCast(u8, mepo.fingers.items.len) };
        }
        break :run_gesture null;
    };

    if (run_gesture_opt) |run_gesture| run: {
        if (run_gesture.direction == .In and mepo.fingers_gesture_delta == delta_max) break :run;
        if (run_gesture.direction == .Out and mepo.fingers_gesture_delta == -delta_max) break :run;
        mepo.fingers_gesture_delta += @as(isize, if (run_gesture.direction == .In) 1 else -1);
        if (mepo.table_gestures.get(run_gesture)) |run_expression| {
            utildbg.log("Got gestures table function with run expression: <{s}>\n", .{run_expression});
            mepo.mepolang_execute(run_expression) catch unreachable;
        }
        return .Redraw;
    }

    return .None;
}

fn event_mousebuttondown(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.fingers.items.len > 1) return .None;

    if (!mepo.within_touch_bounds(e.button.x, e.button.y)) {
        mepo.drag = null;
        return .None;
    } else if (e.button.button == sdl.SDL_BUTTON_LEFT) {
        mepo.drag = .{
            .begin_ticks = sdl.SDL_GetTicks(),
            .point = .{ .x = e.button.x, .y = e.button.y },
        };
    }
    return .Redraw;
}

fn event_mousebuttonup(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.fingers.items.len > 1) return .None;
    defer mepo.drag = null;

    // 1. Invalidation checks: ensure not out of bounds or not dragging
    {
        const is_outside_touch_bounds = !mepo.within_touch_bounds(e.button.x, e.button.y);
        const is_dragging = mepo.drag != null and
            mepo.drag.?.delta_x + mepo.drag.?.delta_y > 10;
        if (is_outside_touch_bounds or is_dragging) return .None;
    }

    // 2. UI on elements clcking overrides (uibtns)
    //    these actions take preference *over* bind_click actions
    if (mepo.blit_uibuttons(e.button) catch null) |clicked_btn| {
        // Click on UI button check
        utildbg.log("Clicked on button: {}\n", .{clicked_btn});
        mepo.mepolang_execute(clicked_btn.mepolang) catch unreachable;
        return .Redraw;
    }

    // 3. Click pin to activate for a single click
    if (e.button.clicks == 1) {
        // Click pin to activate check
        var closest_match_pin: ?struct {
            pin_group_i: u8,
            pin_i: u32,
            delta_dist: i32,
        } = null;
        for (mepo.pin_groups) |pin_group, pin_group_i| {
            if (!pin_group.visible) continue;
            for (pin_group.pins.items) |*item, pin_i| {
                if (item.category == .Structural) continue;
                const pin_x = mepo.convert_latlon_to_xy(.LonToX, item.lon);
                const pin_y = mepo.convert_latlon_to_xy(.LatToY, item.lat);
                const delta = (std.math.absInt(pin_x - e.button.x) catch continue) + (std.math.absInt(pin_y - e.button.y) catch continue);
                if (delta < config.ClickPinMaxDelta and (closest_match_pin == null or closest_match_pin.?.delta_dist > delta)) {
                    closest_match_pin = .{
                        .pin_group_i = @intCast(u8, pin_group_i),
                        .pin_i = @intCast(u32, pin_i),
                        .delta_dist = delta,
                    };
                }
            }
        }
        if (closest_match_pin) |match| {
            mepo.pin_group_active = match.pin_group_i;
            mepo.pin_group_active_item = match.pin_i;
            return .Redraw;
        }
    }

    // 4. Default back to whatever was bound on bind_click by user
    const key = .{ .button = e.button.button, .clicks = @intCast(i8, e.button.clicks) };
    if (mepo.table_clicks.get(key)) |run_expression| {
        utildbg.log("Got click table function {s} for {}\n", .{ run_expression, key });
        mepo.mepolang_execute(run_expression) catch unreachable;
        return .Redraw;
    }

    return .None;
}

fn event_mousemotion(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.fingers.items.len > 1) return .None;

    if (mepo.drag != null and mepo.within_touch_bounds(e.motion.x, e.motion.y)) {
        mepo.drag.?.point.x = e.motion.x;
        mepo.drag.?.point.y = e.motion.y;
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

fn event_keyup(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (sdl.SDL_TRUE == sdl.SDL_IsTextInputActive() and
        e.key.keysym.mod == 0) return .None;
    const key = sdl.SDL_GetScancodeName(e.key.keysym.scancode);
    utildbg.log("Processing key in keyup: {s}\n", .{ key });

    // E.g. don't process anything but single-character hits
    // so things like "Left Shift" etc. are skipped
    if (std.mem.indexOfSentinel(u8, 0, key) != 1) return .None;

    if (mepo.table_keybindings.get(.{
        .key = std.ascii.toLower(key[0]),
        .keymod = keymod: {
            // E.g. within bind_key we store modifiers as KMOD_SHIFT rather then both KMOD_{L,R}SHIFT
            // KMOD_SHIFT is actually (KMOD_LSHIFT | KMOD_RSHIFT)
            // So here we just expand the bitset so the right/left inverse variant is set
            // as such right / left {shift,ctrl,alt} mods always act the same regardless
            var bitset = e.key.keysym.mod;
            for (&[_][2]u16{
                [2]u16{ sdl.KMOD_LSHIFT, sdl.KMOD_RSHIFT },
                [2]u16{ sdl.KMOD_LCTRL, sdl.KMOD_RCTRL },
                [2]u16{ sdl.KMOD_LALT, sdl.KMOD_RALT },
            }) |lr_set| {
                if (bitset & lr_set[0] == lr_set[0]) bitset |= lr_set[1];
                if (bitset & lr_set[1] == lr_set[1]) bitset |= lr_set[0];
            }
            break :keymod bitset;
        },
    })) |run_expression| {
        utildbg.log("Got keybindings table function via keyup with run expression: <{s}>\n", .{run_expression});
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
    // Fix for certain platforms like Phosh like open keyboard on winevents
    defer if (utilplatform.supports_osk()) sdl.SDL_StopTextInput();

    switch (e.window.event) {
        sdl.SDL_WINDOWEVENT_FOCUS_GAINED => {
            sdl.SDL_RaiseWindow(mepo.window);
        },
        sdl.SDL_WINDOWEVENT_RESIZED => {
            var gl_width: c_int = undefined;
            var gl_height: c_int = undefined;
            sdl.SDL_GL_GetDrawableSize(mepo.window, &gl_width, &gl_height);
            utilsdl.errorcheck(sdl.SDL_RenderSetLogicalSize(mepo.renderer, gl_width, gl_height)) catch |err| {
                utildbg.log("Unable to set logical size: {}\n", .{err});
            };
            mepo.win_w = @intCast(u32, gl_width);
            mepo.win_h = @intCast(u32, gl_height);
        },
        else => {
            //utildbg.log("Unhandled SDL Window Event: {s}\n", .{@tagName(@intToEnum(sdl.SDL_WindowEventID, @intCast(c_int, e.window.event)))});
        },
    }
    return .Redraw;
}

fn event_quit(_: *@This(), _: sdl.SDL_Event) types.Pending {
    graceful_terminate();
    return .None;
}

fn event_unhandled(_: *@This(), e: sdl.SDL_Event) types.Pending {
    //utildbg.log("Unhandled SDL Event: {s}\n", .{@tagName(@intToEnum(sdl.SDL_EventType, @intCast(c_int, e.type)))});
    _ = e;
    return .None;
}

pub fn mepolang_execute(mepo: *@This(), mepolang_text: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    // Fairly clean, mepolang parsing/execution works in essentially 3 steps:
    //
    // 1. Tokenize: converts raw text input into tokens so "[];" are always
    //              treated as seperate tokens
    //
    // 2. Statementize: Given tokens, group tokens into statements based on
    //                  semicolons, thus allowing passing compound code.
    //                  Ignore nested [] so statemnts are always 'top-level'.
    //
    // 3. Argize: Given tokens, convert into union values which are actually
    //            type-specific args (like numbers, strings, etc.)
    //
    // Only question remaining re-refactoring is perhaps maybe through a
    // wrapper fn, argize should be a part of statementize? Might be a bit
    // cleaner that way, but either way underlying tests / fn boundaries &
    // API would stay the same..

    for (try utilmepolang.statementize(arena.allocator(), try utilmepolang.tokenize(arena.allocator(), mepolang_text))) |statement| {
        utildbg.log("Executing statment: {s}\n", .{statement});
        if (statement.len < 1) continue;

        // Lookup and run fn
        if (FnTable.get(statement[0])) |func| {
            const args: [types.MepoFnNargs]types.MepoArg = try utilmepolang.argize(arena.allocator(), statement[1..statement.len]);
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
    if (mepo.drag == null or mepo.fingers.items.len > 1) {
        mepo.drag = null;
        return;
    }

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
        sdl.SDL_PumpEvents();
        const has_pending_motion_events = (sdl.SDL_TRUE == sdl.SDL_HasEvent(sdl.SDL_MOUSEMOTION));
        if ((!has_pending_motion_events and pending == .Drag) or pending == .Redraw) {
            try blit(mepo);
        }

        mepo.click_hold_check_dispatch();

        // Process SDL events
        if (sdl.SDL_WaitEventTimeout(&e, config.DragThresholdTicks) > 0) {
            pending = switch (e.type) {
                sdl.SDL_FINGERDOWN => event_fingerdown,
                sdl.SDL_FINGERUP => event_fingerup,
                sdl.SDL_KEYUP => event_keyup,
                sdl.SDL_MOUSEBUTTONDOWN => event_mousebuttondown,
                sdl.SDL_MOUSEBUTTONUP => event_mousebuttonup,
                sdl.SDL_MOUSEMOTION => event_mousemotion,
                sdl.SDL_MOUSEWHEEL => event_mousewheel,
                sdl.SDL_MULTIGESTURE => event_multigesture,
                sdl.SDL_TEXTINPUT => event_textinput,
                sdl.SDL_QUIT => event_quit,
                sdl.SDL_WINDOWEVENT => event_windowevent,
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

fn blit_table(mepo: *@This(), x: i32, y: i32, padding: c_int, rows: []const [2][:0]const u8) !void {
    var width_label: c_int = 0;
    var width_value: c_int = 0;
    var height_row: c_int = 0;

    const border_color = types.Color{ .value = 0x888888, .opacity = 255 };

    // Precalculate width/height for each label
    for (rows) |row| {
        const surf_lab = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderText_Blended(mepo.fonts_bold[mepo.fontsize_ui], @ptrCast([*c]const u8, row[0]), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        defer sdl.SDL_FreeSurface(surf_lab);
        const surf_val = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderText_Blended(mepo.fonts_normal[mepo.fontsize_ui], @ptrCast([*c]const u8, row[1]), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        defer sdl.SDL_FreeSurface(surf_val);
        width_label = std.math.max(width_label, surf_lab.w);
        width_value = std.math.max(width_value, surf_val.w);
        height_row = surf_lab.h;
    }

    // Background color & border
    try utilsdl.sdl_renderer_rect(mepo.renderer, types.Color{ .value = 0xffffff, .opacity = 125 }, sdl.SDL_Rect{
        .x = x,
        .y = y,
        .w = width_label + width_value + padding * 4,
        .h = height_row * @intCast(c_int, rows.len),
    }, .Fill);
    try utilsdl.sdl_renderer_rect(mepo.renderer, border_color, sdl.SDL_Rect{
        .x = x,
        .y = y,
        .w = width_label + width_value + padding * 4,
        .h = height_row * @intCast(c_int, rows.len),
    }, .Draw);

    // Column divider
    try utilsdl.sdl_renderer_rect(mepo.renderer, border_color, sdl.SDL_Rect{
        .x = x + width_label + padding * 2,
        .y = y,
        .w = 1,
        .h = height_row * @intCast(c_int, rows.len),
    }, .Fill);

    for (rows) |row, row_i| {
        // Label
        const surf_lab = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderText_Blended(mepo.fonts_bold[mepo.fontsize_ui], @ptrCast([*c]const u8, row[0]), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        const text_lab = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTextureFromSurface(mepo.renderer, surf_lab));
        defer sdl.SDL_FreeSurface(surf_lab);
        var dest_rect_lab = sdl.SDL_Rect{
            .x = x + padding,
            .y = y + @intCast(c_int, row_i) * height_row,
            .w = surf_lab.w,
            .h = surf_lab.h,
        };
        try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, text_lab, null, &dest_rect_lab));

        // Value
        const surf_value = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderText_Blended(mepo.fonts_normal[mepo.fontsize_ui], @ptrCast([*c]const u8, row[1]), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        const text_value = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTextureFromSurface(mepo.renderer, surf_value));
        defer sdl.SDL_FreeSurface(surf_value);
        var dest_rect_val = sdl.SDL_Rect{
            .x = x + width_label + padding * 3,
            .y = y + @intCast(c_int, row_i) * height_row,
            .w = surf_value.w,
            .h = surf_value.h,
        };
        try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, text_value, null, &dest_rect_val));

        // Horizontal border between rows
        try utilsdl.sdl_renderer_rect(mepo.renderer, border_color, sdl.SDL_Rect{
            .x = x,
            .y = y + @intCast(c_int, row_i) * height_row,
            .w = width_label + width_value + padding * 4,
            .h = 1,
        }, .Fill);
    }
}

pub fn blit_multiline_text(
    mepo: *@This(),
    color: u24,
    border_opt: ?types.Color,
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
            if (font_size > mepo.fonts_normal.len) return error.FontTooBig else break :font_size font_size;
        } else {
            break :font_size mepo.fontsize_ui;
        }
    };

    var textures_width: c_int = 0;
    var textures_height: c_int = 0;

    // Accumulate lines rendered into slice of textures
    var textures: []*sdl.SDL_Texture = textures: {
        var textures_array: [50]*sdl.SDL_Texture = undefined;
        var textures_array_size: usize = 0;

        var lines_it = std.mem.tokenize(u8, msg, "\n");
        while (lines_it.next()) |line| {
            if (textures_array_size + 1 > textures_array.len - 1) break;

            const line_sentinel_terminated = try mepo.allocator.dupeZ(u8, line);
            defer mepo.allocator.free(line_sentinel_terminated);

            const text_surf = try utilsdl.errorcheck_ptr(
                sdl.SDL_Surface,
                sdl.TTF_RenderText_Blended(mepo.fonts_normal[font_size], @ptrCast([*c]const u8, line_sentinel_terminated), (types.Color{ .value = color }).to_sdl()),
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

        // Render border
        if (border_opt) |border|
            try utilsdl.sdl_renderer_rect(mepo.renderer, border, sdl.SDL_Rect{ .x = x_off, .y = y_off, .w = textures_width, .h = textures_height }, .Draw);

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

pub fn init(allocator: std.mem.Allocator, tile_cache: *TileCache, use_sw_renderer: bool, stderr_on: bool, cfg_opt: ?[]const u8) anyerror!@This() {
    // Dump debug info about SDL version compiled/linked
    {
        const version = v: {
            var v: sdl.SDL_version = undefined;
            sdl.SDL_GetVersion(&v);
            break :v v;
        };
        utildbg.log(
            "Compiled against SDL {s}; linked against SDL {s} (version={d}.{d}.{d})\n",
            .{ sdl.SDL_REVISION, sdl.SDL_GetRevision(), version.major, version.minor, version.patch },
        );
    }

    // Initialize SDL video
    video_init: {
        // Attempt to initialize with whatever is set in SDL_VIDEODRIVER
        const env_videodriver_opt = std.process.getEnvVarOwned(allocator, "SDL_VIDEODRIVER") catch null;
        if (env_videodriver_opt) |env_videodriver| env_videoinit: {
            defer allocator.free(env_videodriver);
            const env_videodriver_z = try allocator.dupeZ(u8, env_videodriver);
            defer allocator.free(env_videodriver_z);
            utildbg.log("SDL_VIDEODRIVER env var set to {s}, attempting initialize\n", .{env_videodriver});
            utilsdl.errorcheck(sdl.SDL_VideoInit(env_videodriver_z)) catch |e| {
                utildbg.log("SDL Videodriver {s} failed to initialized: {s}\n", .{ env_videodriver, e });
                break :env_videoinit;
            };
            break :video_init;
        }

        // Use specified order of video drivers to initialize otherwise
        const prefered_sdl_videodrivers_order = &[_][:0]const u8{ "wayland", "x11", "directfb", "kmsdrm" };
        for (prefered_sdl_videodrivers_order) |driver| {
            utildbg.log("SDL Videodriver {s} attempting to initialize\n", .{driver});
            utilsdl.errorcheck(sdl.SDL_VideoInit(driver)) catch |e| {
                utildbg.log("SDL Videodriver {s} failed to initialized: {s}\n", .{ driver, e });
                continue;
            };
            break :video_init;
        }
        utildbg.log("Prefered videodriver failed to initialize; attempting to initializing with default video driver\n", .{});
        try utilsdl.errorcheck(sdl.SDL_VideoInit(null));
    }
    utildbg.log("Successfully initialized SDL with videodriver: {s}\n", .{sdl.SDL_GetCurrentVideoDriver()});

    // Initialize window
    const window = window: {
        const w = try utilsdl.errorcheck_ptr(sdl.SDL_Window, sdl.SDL_CreateWindow(
            "mepo",
            config.InitWindowX,
            config.InitWindowY,
            config.InitWindowW,
            config.InitWindowH,
            sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_ALLOW_HIGHDPI,
        ));
        sdl.SDL_SetWindowPosition(w, config.InitWindowX, config.InitWindowY);

        // E.g. Phosh sometimes doesn't use all space, e.g. strange bar
        // on bottom; so fullscreen & defullscreen to trigger window resize
        if (utilplatform.is_phosh()) {
            _ = sdl.SDL_SetWindowFullscreen(w, sdl.SDL_WINDOW_FULLSCREEN);
            _ = sdl.SDL_SetWindowFullscreen(w, 0);
        }

        break :window w;
    };

    // Initialize SDL Textinput system
    // Controls input for unicode & IME methods etc.
    // Application logic supports both raw keydowns & textinput
    // Also note wtype on sway produces invalid keycodes in keyup
    // so textinput is required here.
    //
    // The textinput system also controls OSK opening & closing.
    // On Phosh this causes issues since there's an overeagerness to
    // open the OSK with textinput (while in reality only shellpipe
    // scripts need the OSK and besides that onscreen keyboard should
    // be hidden).. so for Phosh we disable textinput
    {
        const textinput_enable = !utilplatform.supports_osk();
        if (textinput_enable) sdl.SDL_StartTextInput() else sdl.SDL_StopTextInput();
        utildbg.log("Setting SDL TextInput system to be enabled?: {}\n", .{textinput_enable});
    }

    // Initialize TTF, load fonts
    try utilsdl.errorcheck(sdl.TTF_Init());
    const font_dat = @embedFile("../assets/inconsolata.ttf");

    // Create struct
    var instance = @as(@This(), .{
        .allocator = allocator,
        .fonts_normal = fonts: {
            var fonts: [50]*sdl.TTF_Font = undefined;
            var font_size: usize = 0;
            while (font_size < fonts.len) : (font_size += 1) {
                fonts[font_size] = try utilsdl.errorcheck_ptr(
                    sdl.TTF_Font,
                    sdl.TTF_OpenFontRW(
                        sdl.SDL_RWFromConstMem(@ptrCast(*const anyopaque, &font_dat[0]), font_dat.len),
                        1,
                        @intCast(c_int, font_size),
                    ),
                );
            }
            break :fonts fonts;
        },
        .fonts_bold = fonts: {
            var fonts: [50]*sdl.TTF_Font = undefined;
            var font_size: usize = 0;
            while (font_size < fonts.len) : (font_size += 1) {
                fonts[font_size] = try utilsdl.errorcheck_ptr(
                    sdl.TTF_Font,
                    sdl.TTF_OpenFontRW(
                        sdl.SDL_RWFromConstMem(@ptrCast(*const anyopaque, &font_dat[0]), font_dat.len),
                        1,
                        @intCast(c_int, font_size),
                    ),
                );
                sdl.TTF_SetFontStyle(fonts[font_size], sdl.TTF_STYLE_BOLD);
            }
            break :fonts fonts;
        },
        .fingers = std.ArrayList(sdl.SDL_FingerID).init(allocator),
        .renderer = try utilsdl.errorcheck_ptr(sdl.SDL_Renderer, sdl.SDL_CreateRenderer(
            window,
            -1,
            if (use_sw_renderer) sdl.SDL_RENDERER_SOFTWARE else sdl.SDL_RENDERER_ACCELERATED,
        )),
        .table_gestures = std.array_hash_map.AutoArrayHashMap(types.GestureInput, []const u8).init(allocator),
        .table_keybindings = std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8).init(allocator),
        .table_clicks = std.array_hash_map.AutoArrayHashMap(types.ClickInput, []const u8).init(allocator),
        .table_signals = std.array_hash_map.AutoArrayHashMap(u6, []const u8).init(allocator),
        .tile_cache = tile_cache,
        .uibuttons = std.ArrayList(types.UIButton).init(allocator),
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
        if (stderr_on) try instance.mepolang_execute("prefset debug_stderr 1");
    }

    // Setup TERM/INT signals
    {
        const sigs: [2]u6 = .{ std.os.SIG.TERM, std.os.SIG.INT };
        for (sigs) |sig| {
            std.os.sigaction(sig, &.{
                .handler = .{ .handler = sighandle_terminate },
                .mask = [_]u32{0} ** 32,
                .flags = @as(c_uint, 0),
            }, null);
        }
    }

    return instance;
}

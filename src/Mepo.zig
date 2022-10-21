const std = @import("std");
const sdl = @import("./sdlshim.zig");
const types = @import("./types.zig");
const config = @import("./config.zig");
const errors = @import("./errors.zig");
const TileCache = @import("./TileCache.zig");
const utilconversion = @import("./util/utilconversion.zig");
const utilmepolang = @import("util/utilmepolang.zig");
const utilplatform = @import("util/utilplatform.zig");
const p = @import("util/utilprefs.zig");
const utildbg = @import("util/utildbg.zig");
const utilsdl = @import("util/utilsdl.zig");
const datastructure = @import("datastructure/datastructure.zig");
const zoom_relative = @import("./api/zoom_relative.zig").zoom_relative;
const FnTable = @import("./api/_FnTable.zig");

allocator: std.mem.Allocator,
async_shellpipe_threads: datastructure.QueueHashMap(i8, sdl.SDL_threadID),
config: []const u8,
debug_message: ?[]const u8 = null,
drag: ?struct {
    begin_ticks: u32,
    point: sdl.SDL_Point,
    delta_x: i32 = 0,
    delta_y: i32 = 0,
} = null,
fingers: std.ArrayList(sdl.SDL_FingerID),
fingers_gesture_delta: isize = 0,
fonts_normal: [50]*sdl.TTF_Font,
fonts_bold: [50]*sdl.TTF_Font,
pin_group_active: u8 = 0,
pin_group_active_item: ?u32 = null,
pin_groups: [10]std.ArrayList(types.Pin) = undefined,
renderer: *sdl.SDL_Renderer = undefined,
renderer_sw: bool,
table_gestures: std.array_hash_map.AutoArrayHashMap(types.GestureInput, []const u8),
table_clicks: std.array_hash_map.AutoArrayHashMap(types.ClickInput, []const u8),
table_keybindings: std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8),
table_signals: std.array_hash_map.AutoArrayHashMap(u6, []const u8),
table_timers: std.array_hash_map.AutoArrayHashMap(types.TimerInput, []const u8),
tile_cache: *TileCache,
title_update_ms: usize = 0,
uibuttons: std.ArrayList(types.UIButton),
win_h: u32 = config.InitWindowH,
win_w: u32 = config.InitWindowW,
window: *sdl.SDL_Window = undefined,
quit_action: ?[]const u8 = null,

fn blit_crosshair(mepo: *@This()) errors.SDLError!void {
    try utilsdl.sdl_renderer_set_draw_color(mepo.renderer, .{ .value = 0x000000 });
    try utilsdl.errorcheck(sdl.SDL_RenderDrawLine(
        mepo.renderer,
        @intCast(c_int, mepo.win_w / 2 - (p.get(p.pref.crosshair_size).u / 2)),
        @intCast(c_int, mepo.win_h / 2),
        @intCast(c_int, mepo.win_w / 2 + (p.get(p.pref.crosshair_size).u / 2)),
        @intCast(c_int, mepo.win_h / 2),
    ));
    try utilsdl.errorcheck(sdl.SDL_RenderDrawLine(
        mepo.renderer,
        @intCast(c_int, mepo.win_w / 2),
        @intCast(c_int, mepo.win_h / 2 - (p.get(p.pref.crosshair_size).u / 2)),
        @intCast(c_int, mepo.win_w / 2),
        @intCast(c_int, mepo.win_h / 2 + (p.get(p.pref.crosshair_size).u / 2)),
    ));
}

pub fn blit_tiles_all(mepo: *@This(), bbox: sdl.SDL_Rect, zoom: u8) !void {
    const vpx = utilconversion.lon_to_px_x(p.get(p.pref.lon).f, zoom) - @divTrunc(@intCast(i32, mepo.win_w), 2);
    const vpy = utilconversion.lat_to_px_y(p.get(p.pref.lat).f, zoom) - @divTrunc(@intCast(i32, mepo.win_h), 2);
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
            }
            y += config.Tsize;
            tiley += 1;
        }
        x += config.Tsize;
        tilex += 1;
    }
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
        .queued_position => |_| {
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
                "Queued",
                .{},
            );
        },
        .transfer_datum => |transfer_datum| {
            var dl_now_kb: f64 = 0;
            var dl_total_kb: f64 = 0;
            if (transfer_datum.progress_dl_now) |dln| dl_now_kb = @intToFloat(f64, dln) / 1000;
            if (transfer_datum.progress_dl_total) |dlt| dl_total_kb = @intToFloat(f64, dlt) / 1000;
            var percent: f64 = 0;
            if (dl_total_kb != 0) {
                percent = dl_now_kb / dl_total_kb;
            }

            const color = c: {
                const r = @floatToInt(u24, 255 * percent);
                const g = @floatToInt(u24, 255 * percent);
                const b = @floatToInt(u24, 255 * percent);
                const color: u24 = (r << 16) | (g << 8) | (b << 0);
                break :c color;
            };
            try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = color }, rect_intersect, .Fill);
            try mepo.blit_multiline_text(
                0xffffff,
                null,
                null,
                .{ .w = config.Tsize, .h = config.Tsize, .align_x = .Center, .align_y = .Center },
                @intCast(i32, tile_x * config.Tsize) - x_off,
                @intCast(i32, tile_y * config.Tsize) - y_off,
                null,
                "{d:0.2}%\n{d:0.1}/{d:0.1}Kb",
                .{ percent * 100, dl_now_kb, dl_total_kb },
            );
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
    if (!p.get(p.pref.overlay_pindetails).b) return;

    const d_unit_km = p.get(p.pref.distance_unit_tf_km_mi).b;
    const d_unit = if (d_unit_km) "km" else "mi";

    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    var al = std.ArrayList([2][:0]const u8).init(arena.allocator());
    if (mepo.pin_group_active_item) |_| {
        const pin = mepo.pin_groups[mepo.pin_group_active].items[mepo.pin_group_active_item.?];
        const pin_coords_str = try std.fmt.allocPrintZ(arena.allocator(), "{d:.5} lat / {d:.5} lon", .{ pin.lat, pin.lon });
        const distance_str = try std.fmt.allocPrintZ(arena.allocator(), "{d:.2}{s} away", .{
            utilconversion.distance_haversine(
                if (d_unit_km) .Km else .Mi,
                p.get(p.pref.lat).f,
                p.get(p.pref.lon).f,
                pin.lat,
                pin.lon,
            ),
            d_unit,
        });

        if (pin.handle != null) {
            try al.append(([_][:0]const u8{ "Handle:", pin.handle.? })[0..].*);
        }
        try al.append(([_][:0]const u8{ "Coords:", pin_coords_str })[0..].*);
        if (!p.get(p.pref.overlay_pindetails_expanded).b) {
            try al.append(([_][:0]const u8{ try std.fmt.allocPrintZ(
                arena.allocator(),
                "Group {d}:",
                .{mepo.pin_group_active},
            ), try std.fmt.allocPrintZ(
                arena.allocator(),
                "{d} of {d} ",
                .{
                    mepo.pin_group_active_item.? + 1,
                    mepo.pin_groups[mepo.pin_group_active].items.len,
                },
            ) })[0..].*);
            try al.append(([_][:0]const u8{ "Dist:", distance_str })[0..].*);
            for (pin.metadata.keys()) |k| {
                const duped = try std.fmt.allocPrintZ(arena.allocator(), "{s}", .{k});
                try al.append(([_][:0]const u8{ duped, pin.metadata.get(k).? })[0..].*);
            }
        }
        const off_y = p.get(p.pref.fontsize_ui).u + 26;
        try mepo.blit_table(5, off_y, 5, al.items);
    }
}

fn blit_debugmessage(mepo: *@This()) !void {
    if (p.get(p.pref.debug_message_enabled).b and mepo.debug_message != null) {
        const bottom_off: u32 = if (p.get(p.pref.overlay_debugbar).b) p.get(p.pref.fontsize_ui).u + 10 else 5;
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

fn blit_pin(mepo: *@This(), pin: types.Pin, prev_pin: ?types.Pin, pin_group: u8, pin_color: types.Color, is_active: bool) !void {
    const size: i32 = 10;
    const x = mepo.convert_latlon_to_xy(.LonToX, pin.lon);
    const y = mepo.convert_latlon_to_xy(.LatToY, pin.lat);
    const prev_pin_x = if (prev_pin != null) mepo.convert_latlon_to_xy(.LonToX, prev_pin.?.lon) else undefined;
    const prev_pin_y = if (prev_pin != null) mepo.convert_latlon_to_xy(.LatToY, prev_pin.?.lat) else undefined;

    // Optimization to never drawoff-screen pins
    if ((x < 0 or x > mepo.win_w or y < 0 or y > mepo.win_h) and
        (prev_pin == null or (prev_pin_x < 0 or prev_pin_x > mepo.win_w or prev_pin_y < 0 or prev_pin_y > mepo.win_h))) return;

    // Draw Pin
    if (pin.category == .Instructive) {
        try utilsdl.sdl_renderer_rect(mepo.renderer, pin_color, sdl.SDL_Rect{
            .x = x - @divTrunc(size, 2),
            .y = y - @divTrunc(size, 2),
            .w = size,
            .h = size,
        }, .Fill);
        if (is_active) {
            try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xff0000 }, sdl.SDL_Rect{
                .x = x - @divTrunc(size, 2),
                .y = y - @divTrunc(size, 2),
                .w = size,
                .h = size,
            }, .Draw);
        }
    }

    // Draw Pin label for current pin group
    if (pin.category == .Instructive and mepo.pin_group_active == pin_group) {
        const pin_label_bg : types.Color = bg: {
            if (is_active) {
                break :bg .{ .value = 0xe8e8e8, .opacity = 255 };
            } else {
                break :bg .{ .value = 0xffffff, .opacity = 255 };
            }
        };
        const pin_label_border : types.Color = border: {
            if (is_active) {
                break :border .{ .value = 0x000000, .opacity = 255 };
            } else {
                break :border .{ .value = 0xe8e8e8, .opacity = 255 };
            }
        };
        const label_color : u24 = color: {
            if (is_active) {
                break :color 0x000000;
            } else {
                break :color 0x000000;
            }
        };

        const label = if (pin.metadata.get("name")) |name| name else pin.handle;
        try mepo.blit_multiline_text(
            label_color,
            pin_label_border,
            pin_label_bg,
            .{},
            x,
            y,
            config.ZoomLevelToPinFontSize[p.get(p.pref.zoom).u],
            "{s}",
            .{label},
        );
    }

    // Draw connecting line for ordered pin group
    if (p.get(p.pingroup_prop(pin_group, .Ordered)).b and prev_pin != null) {
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
        var prev_pin: ?*types.Pin = null;
        for (pin_group.items) |*pin, pin_i| {
            defer prev_pin = pin;

            const is_ordered = p.get(p.pingroup_prop(pin_group_i, .Ordered)).b;
            const pg_color = p.get(p.pingroup_prop(pin_group_i, .Color)).u24;
            const is_active = (pin_group_i == mepo.pin_group_active and mepo.pin_group_active_item != null and
                ((is_ordered and ordered_group_active_path) or
                (!is_ordered and mepo.pin_group_active_item.? == pin_i)));

            // E.g. ordered_group_active_path just tracks every time
            // an instructive pin is hit so subsequent structural pins
            // highlighted in "active"/red color until next structural pin
            // hit and full "path" of the active segment of an ordered pin
            // group shows continuously as the active color
            if (mepo.pin_group_active_item != null and mepo.pin_groups[pin_group_i].items[pin_i].category == .Instructive)
                ordered_group_active_path = mepo.pin_group_active_item.? == pin_i;

            try mepo.blit_pin(
                pin.*,
                if (prev_pin != null) prev_pin.?.* else null,
                @intCast(u8, pin_group_i),
                .{ .value = pg_color },
                is_active,
            );
        }
    }

    if (mepo.pin_group_active_item) |active_pin_i| {
        try mepo.blit_pin(
            mepo.pin_groups[mepo.pin_group_active].items[active_pin_i],
            null,
            mepo.pin_group_active,
            .{ .value = p.get(p.pingroup_prop(mepo.pin_group_active, .Color)).u24 },
            true,
        );
    }
}

fn blit_overlay_debugbar(mepo: *@This()) !void {
    if (!p.get(p.pref.overlay_debugbar).b) return;
    const bottombar_height = p.get(p.pref.fontsize_ui).u + 5;

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
        "{d:.3} {d:.3} Z{d} O{d} P{d} Q{d} B{d} D{d} M{d} S{d}",
        .{
            p.get(p.pref.lat).f,
            p.get(p.pref.lon).f,
            p.get(p.pref.zoom).u,
            @boolToInt(mepo.tile_cache.thread_download != null),
            mepo.pin_group_active,
            mepo.tile_cache.queue_lifo_ui.count(),
            mepo.tile_cache.queue_lifo_bg.count(),
            mepo.tile_cache.transfer_map.count(),
            mepo.tile_cache.texture_map.count(),
            mepo.async_shellpipe_threads.count(),
        },
    );
}

fn blit_help(mepo: *@This()) !void {
    if (!p.get(p.pref.help).b) return;

    var msg = msg: {
        var acc = std.ArrayList([]const u8).init(mepo.allocator);
        defer acc.deinit();
        defer for (acc.items) |item| mepo.allocator.free(item);

        var it = mepo.table_keybindings.iterator();

        while (it.next()) |kv| {
            const keymod = utilsdl.sdl_keymod_to_str(kv.key_ptr.keymod);
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
        \\mepo - Development version ({s})
        \\ 
        \\Keybindings:
        \\{s}
    ,
        .{ config.Version, msg },
    );
}

fn blit_uibuttons(mepo: *@This(), determine_click_target: ?sdl.SDL_Point) !?types.UIButton {
    var btn_i = mepo.uibuttons.items.len;
    const pad: c_int = 5;
    var pad_left: c_int = 5;
    var pad_right: c_int = 10;
    const pad_bottom: c_int = p.get(p.pref.fontsize_ui).u + 10;

    while (btn_i > 0) {
        btn_i -= 1;

        if (mepo.uibuttons.items[btn_i].only_visible_when_pin_active and mepo.pin_groups[mepo.pin_group_active].items.len == 0)
            continue;

        const surf = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderText_Blended(mepo.fonts_bold[p.get(p.pref.fontsize_ui).u], @ptrCast([*c]const u8, mepo.uibuttons.items[btn_i].text), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        defer sdl.SDL_FreeSurface(surf);

        const target = target: {
            if (mepo.uibuttons.items[btn_i].only_visible_when_pin_active) {
                const bg_w = surf.w + pad * 2;
                const bg_h = surf.h + pad * 2;
                defer pad_left += bg_w;
                break :target sdl.SDL_Rect{
                    .x = pad_left,
                    .y = 10,
                    .w = bg_w + 1,
                    .h = bg_h + 1,
                };
            } else {
                const bg_w = surf.w + pad * 2;
                const bg_h = surf.h + pad * 2;
                defer pad_right += bg_w;

                break :target sdl.SDL_Rect{
                    .x = @intCast(c_int, mepo.win_w) - pad_right - bg_w,
                    .y = @intCast(c_int, mepo.win_h) - bg_h - pad_bottom,
                    .w = bg_w + 1,
                    .h = bg_h + 1,
                };
            }
        };

        if (determine_click_target) |want_target| {
            // Determine if click fell within btn
            if (want_target.x >= target.x and want_target.y >= target.y and want_target.x <= target.x + target.w and want_target.y <= target.y + target.h) {
                return mepo.uibuttons.items[btn_i];
            }
        } else {
            // Rendering
            const dest_rect_text_lab = sdl.SDL_Rect{
                .x = target.x + pad,
                .y = target.y + pad,
                .w = surf.w,
                .h = surf.h,
            };

            const bg_color = bg_color: {
                if (mepo.drag != null and sdl.SDL_TRUE == sdl.SDL_PointInRect(&mepo.drag.?.point, &dest_rect_text_lab)) {
                    break :bg_color types.Color{ .value = 0xe8e8e8, .opacity = 255 };
                } else if (mepo.uibuttons.items[btn_i].group_number == mepo.pin_group_active) {
                    break :bg_color types.Color{ .value = 0xe8e8e8, .opacity = 255 };
                } else {
                    break :bg_color types.Color{ .value = 0xffffff, .opacity = 125 };
                }
            };

            try utilsdl.sdl_renderer_rect(mepo.renderer, bg_color, target, .Fill);
            try utilsdl.sdl_renderer_rect(mepo.renderer, types.Color{ .value = 0x888888, .opacity = 255 }, target, .Draw);
            if (mepo.uibuttons.items[btn_i].group_number) |group_number| {
                var highlight_rect = target;
                highlight_rect.h = 3;
                highlight_rect.x += 2;
                highlight_rect.y += 2;
                highlight_rect.w -= 4;
                const color = types.Color{ .value = p.get(p.pingroup_prop(group_number, .Color)).u24, .opacity = 255 };
                try utilsdl.sdl_renderer_rect(mepo.renderer, color, highlight_rect, .Fill);
            }
            const text = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTextureFromSurface(mepo.renderer, surf));
            defer sdl.SDL_DestroyTexture(text);
            try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, text, null, &dest_rect_text_lab));
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
        p.get(p.pref.zoom).u,
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
        const title = try std.fmt.allocPrintZ(mepo.allocator, "mepo - {d:.5} lat, {d:.5} lon", .{ p.get(p.pref.lat).f, p.get(p.pref.lon).f });
        defer mepo.allocator.free(title);
        _ = sdl.SDL_SetWindowTitle(mepo.window, title);
    }
}

pub fn convert_latlon_to_xy(mepo: *@This(), lat_or_lon: enum { LonToX, LatToY }, lat_lon_value: f64) i32 {
    return switch (lat_or_lon) {
        .LonToX => -1 * (mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), 2) - utilconversion.lon_to_px_x(lat_lon_value, p.get(p.pref.zoom).u)),
        .LatToY => -1 * (mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), 2) - utilconversion.lat_to_px_y(lat_lon_value, p.get(p.pref.zoom).u)),
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

    const cursor = mepo.scaled_mouse_position();
    if (!mepo.within_touch_bounds(cursor.x, cursor.y)) {
        mepo.drag = null;
        return .None;
    } else if (e.button.button == sdl.SDL_BUTTON_LEFT) {
        mepo.drag = .{
            .begin_ticks = sdl.SDL_GetTicks(),
            .point = .{ .x = cursor.x, .y = cursor.y },
        };
    }
    return .Redraw;
}

fn event_mousebuttonup(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.fingers.items.len > 1) return .None;
    defer mepo.drag = null;

    const cursor = mepo.scaled_mouse_position();

    // 1. Invalidation checks: ensure not out of bounds or not dragging
    {
        const is_outside_touch_bounds = !mepo.within_touch_bounds(cursor.x, cursor.y);
        const is_dragging = mepo.drag != null and
            mepo.drag.?.delta_x + mepo.drag.?.delta_y > 10;
        if (is_outside_touch_bounds or is_dragging) return .None;
    }

    // 2. UI on elements clcking overrides (uibtns)
    //    these actions take preference *over* bind_click actions
    if (mepo.blit_uibuttons(cursor) catch null) |clicked_btn| {
        // Click on UI button check
        utildbg.log("Clicked on button: {} with clicks {}\n", .{clicked_btn, e.button.clicks});
        mepo.mepolang_execute(clicked_btn.mepolang_click_single) catch unreachable;
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
            for (pin_group.items) |*item, pin_i| {
                if (item.category == .Structural) continue;
                const pin_x = mepo.convert_latlon_to_xy(.LonToX, item.lon);
                const pin_y = mepo.convert_latlon_to_xy(.LatToY, item.lat);
                const delta = (std.math.absInt(pin_x - cursor.x) catch continue) + (std.math.absInt(pin_y - cursor.y) catch continue);
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

    const cursor = mepo.scaled_mouse_position();
    if (mepo.drag != null and mepo.within_touch_bounds(cursor.x, cursor.y)) {
        mepo.drag.?.point.x = cursor.x;
        mepo.drag.?.point.y = cursor.y;
        mepo.drag.?.delta_x += std.math.absInt(e.motion.xrel) catch unreachable;
        mepo.drag.?.delta_y += std.math.absInt(e.motion.yrel) catch unreachable;
        mepo.set_x(mepo.get_x() - (e.motion.xrel * p.get(p.pref.drag_scale).u));
        mepo.set_y(mepo.get_y() - (e.motion.yrel * p.get(p.pref.drag_scale).u));
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
    utildbg.log("Processing key in keyup: {s}\n", .{key});

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

fn event_signal(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.table_signals.get(@intCast(u6, e.user.code))) |run_expression| {
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

fn event_mepolangexecution(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    const heap_str = std.mem.sliceTo(@ptrCast([*c]u8, @alignCast(@alignOf([*c]u8), e.user.data1)), 0);
    utildbg.log("SDL mepolang event proccessing: <{s}>\n", .{heap_str});
    mepo.mepolang_execute(heap_str) catch |err| {
        utildbg.log("Error executing mepolang <{s}> caught from SDL event: {}\n", .{ heap_str, err });
    };
    mepo.allocator.free(heap_str);
    return .Redraw;
}

pub fn event_quit(mepo: *@This(), _: sdl.SDL_Event) types.Pending {
    if (mepo.quit_action) |quit_action| {
        mepo.mepolang_execute(quit_action) catch |err| {
            utildbg.log("Error with running mepolang quit action: {}\n", .{err});
        };
    }
    graceful_terminate_sdl();
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
        if (FnTable.get(statement[0])) |fn_spec| {
            const args: []types.MepoArg = try utilmepolang.argize(arena.allocator(), statement[1..statement.len]);
            var caller_args: [types.MepoFnNargs]types.MepoArg = undefined;
            std.mem.copy(types.MepoArg, caller_args[0..], args);

            utildbg.log("Running API function for: {s} requested by mepolang input statement: {s}\n", .{ statement[0], statement });
            _ = mepolang_execute_validate_args(fn_spec, args) catch |e| {
                utildbg.log("Invalid args provided for ({s}) - {any}: (spec args: {d}, given args: {d}) wanted ({any}) but has {any}\n", .{ statement[0], e, fn_spec.args.len, args.len, fn_spec.args, args });
                const err = try std.fmt.allocPrintZ(mepo.allocator, "Invalid args provided for ({s}) - {any}: (spec args: {d}, given args: {d}) wanted ({any}) but has {any}\n", .{ statement[0], e, fn_spec.args.len, args.len, fn_spec.args, args });
                defer mepo.allocator.free(err);
                try mepo.update_debug_message(err);
                return;
            };

            fn_spec.execute(mepo, caller_args) catch |mepolang_err| {
                utildbg.log("Error running API function for: {s}: {}\n", .{ statement[0], mepolang_err });
            };
            try mepo.update_debug_message(null);
        } else if (statement[0].len == 1 and statement[0][0] == '#') {
            // Comment nop
        } else {
            utildbg.log("Requested API function {s} but that's not registered in ftable\n", .{statement[0]});
        }
    }
}

fn mepolang_execute_validate_args(spec: types.MepoFnSpec, args: []types.MepoArg) !bool {
    if (spec.args.len != args.len) return error.NumberOfArgsInvalid;

    for (spec.args) |expect_spec_arg, expect_spec_arg_i| {
        switch (expect_spec_arg.tag) {
            .Number => {
                switch (args[expect_spec_arg_i]) {
                    .Text => {
                        utildbg.log("Expected number, got text in position {} (value={})\n", .{expect_spec_arg_i, args[expect_spec_arg_i]});
                        return error.ExpectNumberGotText;
                    },
                    .Number => continue,
                }
            },
            .Text => {
                switch (args[expect_spec_arg_i]) {
                    .Number => {
                        utildbg.log("Expected text , got number in position {} (value={})\n", .{expect_spec_arg_i, args[expect_spec_arg_i]});
                        return error.ExpectTextGotNumber;
                    },
                    .Text => continue,
                }
            },
        }
    }
    return true;
}

fn dispatch_check_click_hold(mepo: *@This()) void {
    if (mepo.drag == null or mepo.fingers.items.len > 1) {
        mepo.drag = null;
        return;
    }

    const threshold_hit_hold_ms = sdl.SDL_GetTicks() >= mepo.drag.?.begin_ticks + config.DragThresholdTicks;
    const threshold_hit_distance = mepo.drag.?.delta_x + mepo.drag.?.delta_y <= config.DragThresholdDelta;

    // Dispatch held action
    if (threshold_hit_distance) {
        if (mepo.blit_uibuttons(mepo.drag.?.point) catch null) |held_btn| {
            if (threshold_hit_hold_ms) {
                utildbg.log("Held on button: {}\n", .{held_btn});
                mepo.mepolang_execute(held_btn.mepolang_click_hold) catch unreachable;
                mepo.drag = null;
            }
            return;
        }
    }

    if (threshold_hit_hold_ms and threshold_hit_distance) {
        mepo.drag = null;
        // TODO: hold support for right click as well?
        if (mepo.table_clicks.get(.{ .button = sdl.SDL_BUTTON_LEFT, .clicks = -1 })) |run_expression| {
            utildbg.log("Got hold table function {s} after dispatch time\n", .{run_expression});
            mepo.mepolang_execute(run_expression) catch unreachable;
            utilsdl.sdl_push_event_resize();
        }
    }
}

fn dispatch_check_timers(mepo: *@This()) !void {
    var it = mepo.table_timers.iterator();
    while (it.next()) |kv| {
        const timer_input = kv.key_ptr.*;
        const timer_mepolang = kv.value_ptr.*;
        if (sdl.SDL_GetTicks() > timer_input.created_at_ticks + (timer_input.interval_seconds * 1000)) {
            mepo.mepolang_execute(timer_mepolang) catch unreachable;
            const new_timer = .{
                .created_at_ticks = sdl.SDL_GetTicks(),
                .interval_seconds = timer_input.interval_seconds,
            };
            _ = mepo.table_timers.swapRemove(timer_input);
            try mepo.table_timers.put(new_timer, timer_mepolang);
        }
    }
}

pub fn init_video_and_sdl_stdin_loop(mepo: *@This(), enable_stdin_mepolang_repl: bool) !void {
    if (enable_stdin_mepolang_repl) {
        const thread = sdl.SDL_CreateThread(
            mepo_sdl_loop_thread_boot,
            "Mepo_SDL_Thread",
            mepo,
        );
        _ = thread;

        while (true) {
            const stdin = &std.io.getStdIn().reader();
            var read_slice: []const u8 = stdin.readUntilDelimiterAlloc(mepo.allocator, '\n', 102400) catch continue;
            const slice_z = try mepo.allocator.dupeZ(u8, read_slice);
            mepo.allocator.free(read_slice);
            std.debug.print("Read {d} bytes, running input as mepolang\n", .{slice_z.len});
            utilsdl.sdl_push_event_mepolang_execution(slice_z);
        }
    } else {
        _ = mepo_sdl_loop_thread_boot(mepo);
    }
}

fn mepo_sdl_loop_thread_boot(userdata: ?*anyopaque) callconv(.C) c_int {
    var mepo = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata.?));
    video_init(mepo) catch unreachable;
    mepo.mepolang_execute(mepo.config) catch unreachable;
    sdl_event_loop(mepo) catch unreachable;
    return 0;
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

        mepo.dispatch_check_click_hold();
        try mepo.dispatch_check_timers();

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
                else => b: {
                    // Async events triggered outside of main thread:
                    // 1) signals & 2) mepolang trigged via shellpipe or STDIN
                    if (e.type == utilsdl.sdl_usereventtype(.Mepolang)) break :b event_mepolangexecution;
                    if (e.type == utilsdl.sdl_usereventtype(.Signal)) break :b event_signal;
                    // Unhandled case
                    break :b event_unhandled;
                },
            }(mepo, e);
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
            sdl.TTF_RenderText_Blended(mepo.fonts_bold[p.get(p.pref.fontsize_ui).u], @ptrCast([*c]const u8, row[0]), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        defer sdl.SDL_FreeSurface(surf_lab);
        const surf_val = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderText_Blended(mepo.fonts_normal[p.get(p.pref.fontsize_ui).u], @ptrCast([*c]const u8, row[1]), (types.Color{ .value = 0x000000 }).to_sdl()),
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
            sdl.TTF_RenderText_Blended(mepo.fonts_bold[p.get(p.pref.fontsize_ui).u], @ptrCast([*c]const u8, row[0]), (types.Color{ .value = 0x000000 }).to_sdl()),
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
            sdl.TTF_RenderText_Blended(mepo.fonts_normal[p.get(p.pref.fontsize_ui).u], @ptrCast([*c]const u8, row[1]), (types.Color{ .value = 0x000000 }).to_sdl()),
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
            break :font_size p.get(p.pref.fontsize_ui).u;
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
    utilsdl.sdl_push_event_resize();
}


// Returns the scaled mouse position based on the gl_drawablesize which
// is also set on resizes rather then the raw position which comes in
// from GetMouseState
//
// This is used in several places as its more reliable then motion/button
// events which seem to have some issue with SetLogicalSize in certain
// platforms as of SDL 2.0.22
pub fn scaled_mouse_position(mepo: *@This()) sdl.SDL_Point {
    var cursor_x: c_int = undefined;
    var cursor_y: c_int = undefined;
    var gl_w: c_int = undefined;
    var gl_h: c_int = undefined;
    var win_w: c_int = undefined;
    var win_h: c_int = undefined;
    _ = sdl.SDL_GetMouseState(&cursor_x, &cursor_y);
    sdl.SDL_GL_GetDrawableSize(mepo.window, &gl_w, &gl_h);
    sdl.SDL_GetWindowSize(mepo.window, &win_w, &win_h);
    const scale_x = @divTrunc(gl_w, win_w);
    const scale_y = @divTrunc(gl_h, win_h);
    const scaled_x = cursor_x * scale_x;
    const scaled_y = cursor_y * scale_y;
    return .{.x = scaled_x, .y = scaled_y};
}

pub fn cursor_latlon(mepo: *@This()) struct { Lat: f64, Lon: f64 } {
    const cursor = mepo.scaled_mouse_position();

    const cursor_lat = utilconversion.px_y_to_lat(
        mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), 2) + cursor.y,
        p.get(p.pref.zoom).u,
    );
    const cursor_lon = utilconversion.px_x_to_lon(
        mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), 2) + cursor.x,
        p.get(p.pref.zoom).u,
    );

    return .{
        .Lat = cursor_lat,
        .Lon = cursor_lon,
    };
}

pub fn get_x(_: *@This()) i32 {
    return utilconversion.lon_to_px_x(p.get(p.pref.lon).f, p.get(p.pref.zoom).u);
}

pub fn get_y(_: *@This()) i32 {
    return utilconversion.lat_to_px_y(p.get(p.pref.lat).f, p.get(p.pref.zoom).u);
}

pub fn set_x(_: *@This(), x: i32) void {
    p.set_n(p.pref.lon, utilconversion.px_x_to_lon(x, p.get(p.pref.zoom).u));
}

pub fn set_y(_: *@This(), y: i32) void {
    p.set_n(p.pref.lat, utilconversion.px_y_to_lat(y, p.get(p.pref.zoom).u));
}

pub fn bounding_box(mepo: *@This()) types.LatLonBox {
    return .{
        .topleft_lat = utilconversion.px_y_to_lat(mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), @intCast(i32, 2)), p.get(p.pref.zoom).u),
        .topleft_lon = utilconversion.px_x_to_lon(mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), @intCast(i32, 2)), p.get(p.pref.zoom).u),
        .bottomright_lat = utilconversion.px_y_to_lat(mepo.get_y() + @divTrunc(@intCast(i32, mepo.win_h), @intCast(i32, 2)), p.get(p.pref.zoom).u),
        .bottomright_lon = utilconversion.px_x_to_lon(mepo.get_x() + @divTrunc(@intCast(i32, mepo.win_w), @intCast(i32, 2)), p.get(p.pref.zoom).u),
    };
}

pub fn graceful_terminate_sdl() void {
    utildbg.log("Graceful shutdown\n", .{});
    sdl.SDL_VideoQuit();
    sdl.SDL_Quit();
    std.os.exit(0);
}

pub fn sighandle_terminate(arg: c_int) callconv(.C) void {
    utildbg.log("Graceful shutdown via signal: {}", .{arg});
    graceful_terminate_sdl();
}

fn setup_sdl_video_and_window(allocator: std.mem.Allocator) !*sdl.SDL_Window {
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

    // Initialize SDL Hints
    {
        // SDL 2.0.22 introduced a new bug where SDL mouse autocapturing
        // causes touch-emulated mouse motion events to not appear.. disabling
        // mouse autocapturing resolves this.
        // See: https://github.com/libsdl-org/SDL/issues/5652
        _ = sdl.SDL_SetHint("SDL_MOUSE_AUTO_CAPTURE", "0");
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

    // Initialize window
    return window: {
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
        if (utilplatform.xdg_session_desktop() == .Phosh) {
            _ = sdl.SDL_SetWindowFullscreen(w, sdl.SDL_WINDOW_FULLSCREEN);
            _ = sdl.SDL_SetWindowFullscreen(w, 0);
        }

        break :window w;
    };
}

pub fn video_init(mepo: *@This()) !void {
    mepo.window = try setup_sdl_video_and_window(mepo.allocator);
    mepo.renderer = renderer: {
        var r = try utilsdl.errorcheck_ptr(sdl.SDL_Renderer, sdl.SDL_CreateRenderer(
            mepo.window,
            -1,
            if (mepo.renderer_sw) sdl.SDL_RENDERER_SOFTWARE else sdl.SDL_RENDERER_ACCELERATED,
        ));
        break :renderer r;
    };
    mepo.tile_cache.renderer = mepo.renderer;
}

fn init_create_fonts_array(bold: bool) ![50]*sdl.TTF_Font {
    try utilsdl.errorcheck(sdl.TTF_Init());
    const font_dat = @embedFile("../assets/inconsolata.ttf");
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
        if (bold) sdl.TTF_SetFontStyle(fonts[font_size], sdl.TTF_STYLE_BOLD);
    }
    return fonts;
}

pub fn init(allocator: std.mem.Allocator, tile_cache: *TileCache, use_config: []const u8, use_sw_renderer: bool) anyerror!@This() {
    return @as(@This(), .{
        .allocator = allocator,
        .async_shellpipe_threads = datastructure.QueueHashMap(i8, sdl.SDL_threadID).init(allocator),
        .config = use_config,
        .fonts_normal = try init_create_fonts_array(false),
        .fonts_bold = try init_create_fonts_array(true),
        .fingers = std.ArrayList(sdl.SDL_FingerID).init(allocator),
        .table_gestures = std.array_hash_map.AutoArrayHashMap(types.GestureInput, []const u8).init(allocator),
        .table_keybindings = std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8).init(allocator),
        .table_clicks = std.array_hash_map.AutoArrayHashMap(types.ClickInput, []const u8).init(allocator),
        .table_signals = std.array_hash_map.AutoArrayHashMap(u6, []const u8).init(allocator),
        .table_timers = std.array_hash_map.AutoArrayHashMap(types.TimerInput, []const u8).init(allocator),
        .pin_groups = pin_groups: {
            var pgs: [10]std.ArrayList(types.Pin) = undefined;
            for (pgs) |_, i| pgs[i] = std.ArrayList(types.Pin).init(allocator);
            break :pin_groups pgs;
        },
        .tile_cache = tile_cache,
        .uibuttons = std.ArrayList(types.UIButton).init(allocator),
        .renderer_sw = use_sw_renderer,
    });
}

const Mepo = @import("../Mepo.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const types = @import("../types.zig");
const config = @import("../config.zig");
const errors = @import("../errors.zig");
const TileCache = @import("../TileCache.zig");
const utilconversion = @import("../util/utilconversion.zig");
const p = @import("../util/utilprefs.zig");
const utilsdl = @import("../util/utilsdl.zig");

fn blit_crosshair(mepo: *Mepo) errors.SDLError!void {
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

fn blit_tiles_all(mepo: *Mepo, bbox: sdl.SDL_Rect, zoom: u8) !void {
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
                try blit_tile_surface(
                    mepo,
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

fn blit_tile_surface(mepo: *Mepo, tile_x: u32, tile_y: u32, zoom: u8, x_off: i32, y_off: i32, bbox: sdl.SDL_Rect) !void {
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
            try blit_multiline_text(
                mepo,
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
            try blit_multiline_text(
                mepo,
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
            try blit_multiline_text(
                mepo,
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

fn blit_overlay_pindetails(mepo: *Mepo) !void {
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
        if (p.get(p.pref.overlay_pindetails_expanded).b) {
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
        try blit_table(mepo, 5, off_y, 5, al.items);
    }
}

fn blit_debugmessage(mepo: *Mepo) !void {
    if (p.get(p.pref.debug_message_enabled).b and mepo.debug_message != null) {
        const bottom_off: u32 = if (p.get(p.pref.overlay_debugbar).b) p.get(p.pref.fontsize_ui).u + 10 else 5;
        try blit_multiline_text(
            mepo,
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

fn blit_pin(mepo: *Mepo, pin: types.Pin, prev_pin: ?types.Pin, pin_group: u8, is_active: bool, is_active_path: bool) !void {
    try utilsdl.errorcheck(sdl.SDL_SetRenderDrawBlendMode(mepo.renderer, sdl.SDL_BLENDMODE_BLEND));
    const text = sdl.SDL_CreateTexture(
        mepo.renderer,
        sdl.SDL_PIXELFORMAT_UNKNOWN,
        sdl.SDL_TEXTUREACCESS_TARGET,
        config.Tsize,
        config.Tsize,
    );
    try utilsdl.errorcheck(sdl.SDL_SetTextureBlendMode(text, sdl.SDL_BLENDMODE_BLEND));
    try utilsdl.errorcheck(sdl.SDL_SetRenderTarget(mepo.renderer, text));

    const size: i32 = 10;
    const x = mepo.convert_latlon_to_xy(.LonToX, pin.lon);
    const y = mepo.convert_latlon_to_xy(.LatToY, pin.lat);
    const prev_pin_x = if (prev_pin != null) mepo.convert_latlon_to_xy(.LonToX, prev_pin.?.lon) else undefined;
    const prev_pin_y = if (prev_pin != null) mepo.convert_latlon_to_xy(.LatToY, prev_pin.?.lat) else undefined;
    const pg_color = types.Color{ .value = p.get(p.pingroup_prop(pin_group, .Color)).u24 };

    // Optimization to never drawoff-screen pins
    if ((x < 0 or x > mepo.win_w or y < 0 or y > mepo.win_h) and
        (prev_pin == null or (prev_pin_x < 0 or prev_pin_x > mepo.win_w or prev_pin_y < 0 or prev_pin_y > mepo.win_h))) return;

    // Draw connecting line for ordered pin group
    if (p.get(p.pingroup_prop(pin_group, .Ordered)).b and prev_pin != null) {
        const connecting_line_color = if (is_active_path) 0xff0000ff else pg_color.to_u32();
        try utilsdl.errorcheck(sdl.aalineColor(
            mepo.renderer,
            @intCast(i16, prev_pin_x),
            @intCast(i16, prev_pin_y),
            @intCast(i16, x),
            @intCast(i16, y),
            connecting_line_color,
        ));
    }

    // Draw Pin
    if (pin.category == .Instructive) {
        try utilsdl.sdl_renderer_rect(mepo.renderer, pg_color, sdl.SDL_Rect{
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
        const pin_label_bg: types.Color = bg: {
            if (is_active) {
                break :bg .{ .value = 0xe8e8e8, .opacity = 255 };
            } else {
                break :bg .{ .value = 0xffffff, .opacity = 255 };
            }
        };
        const pin_label_border: types.Color = border: {
            if (is_active) {
                break :border .{ .value = 0x000000, .opacity = 255 };
            } else {
                break :border .{ .value = 0xe8e8e8, .opacity = 255 };
            }
        };
        const label_color: u24 = 0x000000;

        const label = lab: {
            if (pin.metadata.get("name")) |name| break :lab name;
            if (pin.handle) |h| break :lab h;
            break :lab "";
        };

        try blit_multiline_text(
            mepo,
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

    const from = sdl.SDL_Rect{ .x = 0, .y = 0, .w = 256, .h = 256 };
    try utilsdl.errorcheck(sdl.SDL_SetRenderTarget(mepo.renderer, null));
    try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, text, &from, &from));
    try utilsdl.errorcheck(sdl.SDL_SetRenderDrawBlendMode(mepo.renderer, sdl.SDL_BLENDMODE_NONE));
    defer sdl.SDL_DestroyTexture(text);
}

fn blit_pins(mepo: *Mepo) !void {
    for (order: {
        // E.g. place active pingroup last so its always ontop in rendering order
        var groups = [10]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
        var target_order: [10]u8 = undefined;
        var index: u8 = 0;
        for (groups) |i| {
            if (i == mepo.pin_group_active) continue;
            target_order[index] = i;
            index += 1;
        }
        target_order[9] = mepo.pin_group_active;
        break :order target_order;
    }) |pin_group_i| {
        const pin_group = mepo.pin_groups[pin_group_i];
        var ordered_group_active_path = false;
        var prev_pin: ?*types.Pin = null;
        for (pin_group.items) |*pin, pin_i| {
            defer prev_pin = pin;

            const is_active = mepo.pin_group_active_item != null and mepo.pin_group_active_item.? == pin_i;
            const is_active_path = is_active_path: {
                const is_ordered = p.get(p.pingroup_prop(pin_group_i, .Ordered)).b;
                break :is_active_path (pin_group_i == mepo.pin_group_active and mepo.pin_group_active_item != null and
                    ((is_ordered and ordered_group_active_path) or
                    (!is_ordered and mepo.pin_group_active_item.? == pin_i)));
            };

            // E.g. ordered_group_active_path just tracks every time
            // an instructive pin is hit so subsequent structural pins
            // highlighted in "active"/red color until next structural pin
            // hit and full "path" of the active segment of an ordered pin
            // group shows continuously as the active color
            if (mepo.pin_group_active_item != null and mepo.pin_groups[pin_group_i].items[pin_i].category == .Instructive)
                ordered_group_active_path = mepo.pin_group_active_item.? == pin_i;

            try blit_pin(
                mepo,
                pin.*,
                if (prev_pin != null) prev_pin.?.* else null,
                @intCast(u8, pin_group_i),
                is_active,
                is_active_path,
            );
        }
    }

    if (mepo.pin_group_active_item) |active_pin_i| {
        try blit_pin(
            mepo,
            mepo.pin_groups[mepo.pin_group_active].items[active_pin_i],
            null,
            mepo.pin_group_active,
            true,
            false,
        );
    }
}

fn blit_overlay_debugbar(mepo: *Mepo) !void {
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
    try blit_multiline_text(
        mepo,
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
    try blit_multiline_text(
        mepo,
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

fn blit_help(mepo: *Mepo) !void {
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

    try blit_multiline_text(
        mepo,
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


fn blit_table(mepo: *Mepo, x: i32, y: i32, padding: c_int, rows: []const [2][:0]const u8) !void {
    var width_label: c_int = 0;
    var width_value: c_int = 0;
    var height_row: c_int = 0;

    const border_color = types.Color{ .value = 0x888888, .opacity = 255 };

    // Precalculate width/height for each label
    for (rows) |row| {
        const surf_lab = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderUTF8_Blended(mepo.fonts_bold[p.get(p.pref.fontsize_ui).u], @ptrCast([*c]const u8, row[0]), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        defer sdl.SDL_FreeSurface(surf_lab);
        const surf_val = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderUTF8_Blended(mepo.fonts_normal[p.get(p.pref.fontsize_ui).u], @ptrCast([*c]const u8, row[1]), (types.Color{ .value = 0x000000 }).to_sdl()),
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
            sdl.TTF_RenderUTF8_Blended(mepo.fonts_bold[p.get(p.pref.fontsize_ui).u], @ptrCast([*c]const u8, row[0]), (types.Color{ .value = 0x000000 }).to_sdl()),
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
            sdl.TTF_RenderUTF8_Blended(mepo.fonts_normal[p.get(p.pref.fontsize_ui).u], @ptrCast([*c]const u8, row[1]), (types.Color{ .value = 0x000000 }).to_sdl()),
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

fn blit_multiline_text(
    mepo: *Mepo,
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
                sdl.TTF_RenderUTF8_Blended(mepo.fonts_normal[font_size], @ptrCast([*c]const u8, line_sentinel_terminated), (types.Color{ .value = color }).to_sdl()),
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

        // Render text
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

pub fn blit_uibuttons(mepo: *Mepo, determine_click_target: ?sdl.SDL_Point) !?types.UIButton {
    var btn_i = mepo.uibuttons.items.len;
    const pad: c_int = 5;
    var pad_left: c_int = 5;
    var pad_right: c_int = 10;
    const pad_bottom: c_int = p.get(p.pref.fontsize_ui).u + 10;

    while (btn_i > 0) {
        btn_i -= 1;

        if (mepo.uibuttons.items[btn_i].only_visible_when_pin_active and mepo.pin_group_active_item == null)
            continue;

        const surf = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderUTF8_Blended(mepo.fonts_bold[p.get(p.pref.fontsize_ui).u], @ptrCast([*c]const u8, mepo.uibuttons.items[btn_i].text), (types.Color{ .value = 0x000000 }).to_sdl()),
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

pub fn blit(mepo: *Mepo) !void {
    try utilsdl.errorcheck(sdl.SDL_RenderClear(mepo.renderer));
    try utilsdl.sdl_renderer_rect(
        mepo.renderer,
        .{ .value = 0xffffff },
        .{ .x = 0, .y = 0, .w = @intCast(c_int, mepo.win_w), .h = @intCast(c_int, mepo.win_h) },
        .Fill,
    );
    try blit_tiles_all(
        mepo,
        .{
            .x = 0,
            .y = 0,
            .w = @intCast(c_int, mepo.win_w),
            .h = @intCast(c_int, mepo.win_h),
        },
        p.get(p.pref.zoom).u,
    );
    try blit_pins(mepo);
    try blit_crosshair(mepo);
    try blit_overlay_pindetails(mepo);
    try blit_overlay_debugbar(mepo);
    try blit_help(mepo);
    try blit_debugmessage(mepo);
    _ = try blit_uibuttons(mepo, null);

    sdl.SDL_RenderPresent(mepo.renderer);

    // Update title, this is actually a relatively slow operation on certain
    // platforms such as Wayland/Phosh; thus we only update at a certain
    // specified config frequency
    if (sdl.SDL_GetTicks() > mepo.title_update_ms + config.TitleUpdateFrequencyMs) {
        mepo.title_update_ms = sdl.SDL_GetTicks();
        const title = try std.fmt.allocPrintZ(mepo.allocator, "mepo - {d:.5} lat, {d:.5} lon", .{ p.get(p.pref.lat).f, p.get(p.pref.lon).f });
        defer mepo.allocator.free(title);
        _ = sdl.SDL_SetWindowTitle(mepo.window, &title[0]);
    }
}


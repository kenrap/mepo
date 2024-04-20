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
const utildbg = @import("../util/utildbg.zig");

fn blit_crosshair(mepo: *Mepo) errors.SDLError!void {
    try utilsdl.sdl_renderer_set_draw_color(mepo.renderer, .{ .value = 0x000000 });
    try utilsdl.errorcheck(sdl.SDL_RenderDrawLine(
        mepo.renderer,
        @intCast(mepo.win_w / 2 - (p.get(p.pref.crosshair_size).u / 2)),
        @intCast(mepo.win_h / 2),
        @intCast(mepo.win_w / 2 + (p.get(p.pref.crosshair_size).u / 2)),
        @intCast(mepo.win_h / 2),
    ));
    try utilsdl.errorcheck(sdl.SDL_RenderDrawLine(
        mepo.renderer,
        @intCast(mepo.win_w / 2),
        @intCast(mepo.win_h / 2 - (p.get(p.pref.crosshair_size).u / 2)),
        @intCast(mepo.win_w / 2),
        @intCast(mepo.win_h / 2 + (p.get(p.pref.crosshair_size).u / 2)),
    ));
}

fn blit_tiles_all(mepo: *Mepo, bbox: sdl.SDL_Rect, zoom: u8) !void {
    const vpx = utilconversion.lon_to_px_x(p.get(p.pref.lon).f, zoom) - @as(i32, @intCast(mepo.win_w / 2));
    const vpy = utilconversion.lat_to_px_y(p.get(p.pref.lat).f, zoom) - @as(i32, @intCast(mepo.win_h / 2));
    const begx = vpx - config.Tsize;
    const begy = vpy - config.Tsize;
    const endx = vpx + @as(i32, @intCast(bbox.w)) + config.Tsize;
    const endy = vpy + @as(i32, @intCast(bbox.h)) + config.Tsize;

    var tilex: i32 = @intCast(@divFloor(begx, config.Tsize));
    var tiley: i32 = @intCast(@divFloor(begy, config.Tsize));

    var x = begx;
    while (x < endx) {
        var y = begy;
        tiley = @intCast(@divFloor(begy, config.Tsize));
        while (y < endy) {
            if (tilex >= 0 and tiley >= 0 and tilex <= std.math.pow(u32, 2, zoom) - 1 and tiley <= std.math.pow(u32, 2, zoom) - 1) {
                const tilex_int: u32 = @intCast(tilex);
                const tiley_int: u32 = @intCast(tiley);
                try blit_tile_surface(mepo, tilex_int, tiley_int, zoom, vpx, vpy, bbox);
                try blit_tile_pinlayer(mepo, tilex_int, tiley_int, zoom, vpx, vpy, bbox);
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
        .x = @as(i32, @intCast(tile_x * config.Tsize)) - x_off,
        .y = @as(i32, @intCast(tile_y * config.Tsize)) - y_off,
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
                @as(i32, @intCast(tile_x * config.Tsize)) - x_off,
                @as(i32, @intCast(tile_y * config.Tsize)) - y_off,
                20,
                "Queued",
                .{},
            );
        },
        .transfer_datum => |transfer_datum| {
            var dl_now_kb: f64 = 0;
            var dl_total_kb: f64 = 0;
            if (transfer_datum.progress_dl_now) |dln| dl_now_kb = @as(f64, @floatFromInt(dln)) / 1000;
            if (transfer_datum.progress_dl_total) |dlt| dl_total_kb = @as(f64, @floatFromInt(dlt)) / 1000;
            var percent: f64 = 0;
            if (dl_total_kb != 0) {
                percent = dl_now_kb / dl_total_kb;
            }

            const color = c: {
                const r = @as(u24, @intFromFloat(255 * percent));
                const g = @as(u24, @intFromFloat(255 * percent));
                const b = @as(u24, @intFromFloat(255 * percent));
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
                @as(i32, @intCast(tile_x * config.Tsize)) - x_off,
                @as(i32, @intCast(tile_y * config.Tsize)) - y_off,
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
                @as(i32, @intCast(tile_x * config.Tsize)) - x_off,
                @as(i32, @intCast(tile_y * config.Tsize)) - y_off,
                20,
                "Offline",
                .{},
            );
        },
    }
}

fn blit_tile_pinlayer(mepo: *Mepo, tile_x: u32, tile_y: u32, zoom: u8, x_off: i32, y_off: i32, bbox: sdl.SDL_Rect) !void {
    const rect_dest = sdl.SDL_Rect{
        .x = @as(i32, @intCast(tile_x * config.Tsize)) - x_off,
        .y = @as(i32, @intCast(tile_y * config.Tsize)) - y_off,
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

    if (mepo.blit_pinlayer_cache.get(.{ .x = tile_x, .y = tile_y, .z = zoom })) |text| {
        utildbg.log("Pinlayer cache hit {}\n", .{.{ .x = tile_x, .y = tile_y, .z = zoom }});
        try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, text, &rect_src, &rect_intersect));
    } else {
        utildbg.log("Pinlayer cache miss {}\n", .{.{ .x = tile_x, .y = tile_y, .z = zoom }});
        const text = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTexture(
            mepo.renderer,
            sdl.SDL_PIXELFORMAT_UNKNOWN,
            sdl.SDL_TEXTUREACCESS_TARGET,
            config.Tsize,
            config.Tsize,
        ));
        try utilsdl.errorcheck(sdl.SDL_SetTextureBlendMode(text, sdl.SDL_BLENDMODE_BLEND));
        try utilsdl.errorcheck(sdl.SDL_SetRenderTarget(mepo.renderer, text));
        try utilsdl.errorcheck(sdl.SDL_SetRenderDrawColor(mepo.renderer, 0, 0, 0, 0));
        try utilsdl.errorcheck(sdl.SDL_RenderClear(mepo.renderer));

        // Rendering Logic
        {
            const pingroup_order = order: {
                // E.g. place active pingroup last so its always ontop in rendering order
                const groups = [10]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
                var target_order: [10]u8 = undefined;
                var index: u8 = 0;
                for (groups) |i| {
                    if (i == mepo.pin_group_active) continue;
                    target_order[index] = i;
                    index += 1;
                }
                target_order[9] = mepo.pin_group_active;
                break :order target_order;
            };

            for (pingroup_order) |pin_group_i| {
                const pin_group = mepo.pin_groups[pin_group_i];
                var is_active_path_track = false;
                var prev_pin: ?*types.Pin = null;
                for (pin_group.items, 0..) |*pin, pin_i| {
                    defer prev_pin = pin;

                    // is_active_path: Whether path from prevpin to pin red
                    // is_active_path_track: Track if next pin along instructive
                    //                       pin highlighted track
                    const is_active_path = is_active_path: {
                        const is_ordered = p.get(p.pingroup_prop(pin_group_i, .Ordered)).b;
                        break :is_active_path (pin_group_i == mepo.pin_group_active and mepo.pin_group_active_item != null and
                            ((is_ordered and is_active_path_track) or
                            (!is_ordered and mepo.pin_group_active_item.? == pin_i)));
                    };
                    is_active_path_track = track: {
                        const has_active_pg_item = mepo.pin_group_active_item != null;
                        const is_instructive_pin = mepo.pin_groups[pin_group_i].items[pin_i].category == .Instructive;
                        const is_active_pin = has_active_pg_item and mepo.pin_group_active_item.? == pin_i;

                        if (has_active_pg_item and is_instructive_pin) {
                            break :track is_active_pin;
                        } else {
                            break :track is_active_path_track;
                        }
                    };

                    try blit_pin(mepo, pin, if (prev_pin != null) prev_pin else null, @intCast(pin_group_i), is_active_path, .{ .x = tile_x, .y = tile_y, .z = zoom });
                }
            }

            if (mepo.pin_group_active_item) |active_pin_i| {
                try blit_pin(mepo, &mepo.pin_groups[mepo.pin_group_active].items[active_pin_i], null, mepo.pin_group_active, true, .{ .x = tile_x, .y = tile_y, .z = zoom });
            }
        }

        _ = try mepo.blit_pinlayer_cache.put(.{ .x = tile_x, .y = tile_y, .z = zoom }, text);
        try utilsdl.errorcheck(sdl.SDL_SetRenderTarget(mepo.renderer, null));
        try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, text, &rect_src, &rect_intersect));
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

fn get_pin_xyz_and_offsets(pin: *types.Pin, for_zoom: u8) types.XYZAndOffsets {
    const pinx = utilconversion.lon_to_px_x(pin.lon, for_zoom);
    const piny = utilconversion.lat_to_px_y(pin.lat, for_zoom);
    return .{
        .xyz = .{
            .x = @intCast(@divFloor(pinx, config.Tsize)),
            .y = @intCast(@divFloor(piny, config.Tsize)),
            .z = for_zoom,
        },
        .offset = .{
            .x = @intCast(@rem(pinx, config.Tsize)),
            .y = @intCast(@rem(piny, config.Tsize)),
        },
    };
}

fn blit_pin(mepo: *Mepo, pin: *types.Pin, prev_pin: ?*types.Pin, pin_group: u8, is_active_path: bool, for_tile: types.XYZ) !void {
    const pin_rect_size: i32 = 10;
    const is_active = mepo.pin_group_active_item != null and &mepo.pin_groups[mepo.pin_group_active].items[mepo.pin_group_active_item.?] == pin;

    const pindest = get_pin_xyz_and_offsets(pin, for_tile.z);
    const pin_target_x = ((@as(c_int, @intCast(pindest.xyz.x)) - @as(c_int, @intCast(for_tile.x))) * config.Tsize) + @as(c_int, @intCast(pindest.offset.x));
    const pin_target_y = ((@as(c_int, @intCast(pindest.xyz.y)) - @as(c_int, @intCast(for_tile.y))) * config.Tsize) + @as(c_int, @intCast(pindest.offset.y));
    var prevpin_target_x: ?i32 = null;
    var prevpin_target_y: ?i32 = null;
    if (prev_pin != null) {
        const prevpindest = get_pin_xyz_and_offsets(prev_pin.?, for_tile.z);
        prevpin_target_x = ((@as(c_int, @intCast(prevpindest.xyz.x)) - @as(c_int, @intCast(for_tile.x))) * config.Tsize) + @as(c_int, @intCast(prevpindest.offset.x));
        prevpin_target_y = ((@as(c_int, @intCast(prevpindest.xyz.y)) - @as(c_int, @intCast(for_tile.y))) * config.Tsize) + @as(c_int, @intCast(prevpindest.offset.y));
    }

    // 0. Nop Check - ensure that rendered pin/connecting line within tile
    {
        const font_height: i8 = @intCast(config.ZoomLevelToPinFontSize[p.get(p.pref.zoom).u]);
        const n_tiles_font_overlap = 2;
        const pin_in_view = r: {
            const a = pin_target_x > (-config.Tsize * n_tiles_font_overlap) and pin_target_x < (config.Tsize * n_tiles_font_overlap);
            const b = pin_target_y > -font_height and pin_target_y - (pin_rect_size / 2) < config.Tsize;
            break :r a and b;
        };
        const prevpin_in_view = r: {
            if (prev_pin == null) break :r false;
            const a = prevpin_target_x.? > (-config.Tsize * n_tiles_font_overlap) and prevpin_target_x.? < config.Tsize * n_tiles_font_overlap;
            const b = prevpin_target_y.? > -font_height and prevpin_target_y.? - (pin_rect_size / 2) < config.Tsize;
            break :r a and b;
        };
        const connecting_line_in_view = r: {
            if (prev_pin == null) break :r false;
            const prevpindest = get_pin_xyz_and_offsets(prev_pin.?, for_tile.z);
            var x1: c_int = @intCast(pindest.xyz.x * config.Tsize + pindest.offset.x);
            var y1: c_int = @intCast(pindest.xyz.y * config.Tsize + pindest.offset.y);
            var x2: c_int = @intCast(prevpindest.xyz.x * config.Tsize + prevpindest.offset.x);
            var y2: c_int = @intCast(prevpindest.xyz.y * config.Tsize + prevpindest.offset.y);
            const rect = sdl.SDL_Rect{
                .x = @intCast(for_tile.x * config.Tsize),
                .y = @intCast(for_tile.y * config.Tsize),
                .w = config.Tsize,
                .h = config.Tsize,
            };
            break :r sdl.SDL_IntersectRectAndLine(&rect, &x1, &y1, &x2, &y2) == sdl.SDL_TRUE;
        };

        if (!pin_in_view and !prevpin_in_view and !connecting_line_in_view) return;
    }

    // 1. Render the path from the previous pin in ordered pin group
    render_connecting_line: {
        if (!p.get(p.pingroup_prop(pin_group, .Ordered)).b or prev_pin == null)
            break :render_connecting_line;

        const pg_color = types.Color{ .value = p.get(p.pingroup_prop(pin_group, .Color)).u24 };
        const connecting_line_color = if (is_active_path) 0xff0000ff else pg_color.to_u32();
        try utilsdl.errorcheck(sdl.aalineColor(
            mepo.renderer,
            @intCast(prevpin_target_x.?),
            @intCast(prevpin_target_y.?),
            @intCast(pin_target_x),
            @intCast(pin_target_y),
            connecting_line_color,
        ));
    }

    // 2. Render the pin square
    render_pin_square: {
        if (pin.category != .Instructive) break :render_pin_square;

        const pg_color = types.Color{ .value = p.get(p.pingroup_prop(pin_group, .Color)).u24 };
        const dest_rect = sdl.SDL_Rect{
            .x = pin_target_x - @divTrunc(pin_rect_size, 2),
            .y = pin_target_y - @divTrunc(pin_rect_size, 2),
            .w = pin_rect_size,
            .h = pin_rect_size,
        };
        try utilsdl.sdl_renderer_rect(mepo.renderer, pg_color, dest_rect, .Fill);
        if (is_active) {
            try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xff0000 }, dest_rect, .Draw);
        }
    }

    // 3. Render the pin label (only applies for the current pin group)
    render_pin_label: {
        if (pin.category != .Instructive or mepo.pin_group_active != pin_group)
            break :render_pin_label;

        const pin_label_bg_value: u24 = if (is_active) 0xe8e8e8 else 0xffffff;
        const pin_label_bg: types.Color = .{ .value = pin_label_bg_value, .opacity = 255 };
        const pin_label_border_value: u24 = if (is_active) 0x000000 else 0xe8e8e8;
        const pin_label_border = .{ .value = pin_label_border_value, .opacity = 255 };

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
            pin_target_x,
            pin_target_y,
            config.ZoomLevelToPinFontSize[p.get(p.pref.zoom).u],
            "{s}",
            .{label},
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
        .y = @as(i32, @intCast(mepo.win_h)) - bottombar_height,
        .w = @intCast(mepo.win_w),
        .h = 200,
    }, .Fill);
    try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0x000000 }, sdl.SDL_Rect{
        .x = 0,
        .y = @as(i32, @intCast(mepo.win_h)) - bottombar_height,
        .w = @intCast(mepo.win_w),
        .h = 1,
    }, .Fill);
    try blit_multiline_text(
        mepo,
        0x000000,
        null,
        null,
        .{ .align_x = .Right },
        0,
        @as(i32, @intCast(mepo.win_h)) - bottombar_height + 3,
        null,
        "Dl: {d:.2}Mb ",
        .{@as(f32, @floatFromInt(mepo.tile_cache.byte_counter)) / 1024 / 1024},
    );
    try blit_multiline_text(
        mepo,
        0x000000,
        null,
        null,
        .{},
        5,
        @as(i32, @intCast(mepo.win_h)) - bottombar_height + 3,
        null,
        "{d:.3} {d:.3} Z{d} O{d} P{d} Q{d} B{d} D{d} M{d} S{d}",
        .{
            p.get(p.pref.lat).f,
            p.get(p.pref.lon).f,
            p.get(p.pref.zoom).u,
            @intFromBool(mepo.tile_cache.thread_download != null),
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

    const msg = msg: {
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
        \\mepo - Version ({s})
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
            sdl.TTF_RenderUTF8_Blended(mepo.fonts_bold[p.get(p.pref.fontsize_ui).u], @ptrCast(row[0]), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        defer sdl.SDL_FreeSurface(surf_lab);
        const surf_val = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderUTF8_Blended(mepo.fonts_normal[p.get(p.pref.fontsize_ui).u], @ptrCast(row[1]), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        defer sdl.SDL_FreeSurface(surf_val);
        width_label = @max(width_label, surf_lab.w);
        width_value = @max(width_value, surf_val.w);
        height_row = surf_lab.h;
    }

    // Background color & border
    try utilsdl.sdl_renderer_rect(mepo.renderer, types.Color{ .value = 0xffffff, .opacity = 125 }, sdl.SDL_Rect{
        .x = x,
        .y = y,
        .w = width_label + width_value + padding * 4,
        .h = height_row * @as(c_int, @intCast(rows.len)),
    }, .Fill);
    try utilsdl.sdl_renderer_rect(mepo.renderer, border_color, sdl.SDL_Rect{
        .x = x,
        .y = y,
        .w = width_label + width_value + padding * 4,
        .h = height_row * @as(c_int, @intCast(rows.len)),
    }, .Draw);

    // Column divider
    try utilsdl.sdl_renderer_rect(mepo.renderer, border_color, sdl.SDL_Rect{
        .x = x + width_label + padding * 2,
        .y = y,
        .w = 1,
        .h = height_row * @as(c_int, @intCast(rows.len)),
    }, .Fill);

    for (rows, 0..) |row, row_i| {
        // Label
        const surf_lab = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderUTF8_Blended(mepo.fonts_bold[p.get(p.pref.fontsize_ui).u], @ptrCast(row[0]), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        const text_lab = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTextureFromSurface(mepo.renderer, surf_lab));
        defer sdl.SDL_FreeSurface(surf_lab);
        var dest_rect_lab = sdl.SDL_Rect{
            .x = x + padding,
            .y = y + @as(c_int, @intCast(row_i)) * height_row,
            .w = surf_lab.w,
            .h = surf_lab.h,
        };
        try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, text_lab, null, &dest_rect_lab));

        // Value
        const surf_value = try utilsdl.errorcheck_ptr(
            sdl.SDL_Surface,
            sdl.TTF_RenderUTF8_Blended(mepo.fonts_normal[p.get(p.pref.fontsize_ui).u], @ptrCast(row[1]), (types.Color{ .value = 0x000000 }).to_sdl()),
        );
        const text_value = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTextureFromSurface(mepo.renderer, surf_value));
        defer sdl.SDL_FreeSurface(surf_value);
        var dest_rect_val = sdl.SDL_Rect{
            .x = x + width_label + padding * 3,
            .y = y + @as(c_int, @intCast(row_i)) * height_row,
            .w = surf_value.w,
            .h = surf_value.h,
        };
        try utilsdl.errorcheck(sdl.SDL_RenderCopy(mepo.renderer, text_value, null, &dest_rect_val));

        // Horizontal border between rows
        try utilsdl.sdl_renderer_rect(mepo.renderer, border_color, sdl.SDL_Rect{
            .x = x,
            .y = y + @as(c_int, @intCast(row_i)) * height_row,
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
    const msg = try std.fmt.allocPrintZ(mepo.allocator, fmt_string, args);
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
    const textures: []*sdl.SDL_Texture = textures: {
        var textures_array: [50]*sdl.SDL_Texture = undefined;
        var textures_array_size: usize = 0;

        var lines_it = std.mem.tokenize(u8, msg, "\n");
        while (lines_it.next()) |line| {
            if (textures_array_size + 1 > textures_array.len - 1) break;

            const line_sentinel_terminated = try mepo.allocator.dupeZ(u8, line);
            defer mepo.allocator.free(line_sentinel_terminated);

            const text_surf = try utilsdl.errorcheck_ptr(
                sdl.SDL_Surface,
                sdl.TTF_RenderUTF8_Blended(mepo.fonts_normal[font_size], @ptrCast(line_sentinel_terminated), (types.Color{ .value = color }).to_sdl()),
            );
            defer sdl.SDL_FreeSurface(text_surf);

            const text = try utilsdl.errorcheck_ptr(sdl.SDL_Texture, sdl.SDL_CreateTextureFromSurface(mepo.renderer, text_surf));
            textures_height += text_surf.h;
            textures_width = @max(textures_width, text_surf.w);
            textures_array[textures_array_size] = text;
            textures_array_size += 1;
        }

        break :textures textures_array[0..textures_array_size];
    };

    // Rendering
    {
        // Calculate X/Y offsets
        const x_off: c_int = x_off: {
            const bbox_total_w: c_int = @intCast(if (alignment.w) |w| w else mepo.win_w);
            const offset = switch (alignment.align_x) {
                .Left => 0,
                .Right => bbox_total_w - textures_width,
                .Center => @divTrunc(bbox_total_w - textures_width, 2),
            };
            break :x_off x + offset;
        };
        var y_off: c_int = y_off: {
            const bbox_total_h: c_int = @intCast(if (alignment.h) |h| h else mepo.win_h);
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
            sdl.TTF_RenderUTF8_Blended(mepo.fonts_bold[p.get(p.pref.fontsize_ui).u], @ptrCast(mepo.uibuttons.items[btn_i].text), (types.Color{ .value = 0x000000 }).to_sdl()),
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
                    .x = @as(c_int, @intCast(mepo.win_w)) - pad_right - bg_w,
                    .y = @as(c_int, @intCast(mepo.win_h)) - bg_h - pad_bottom,
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
        .{ .x = 0, .y = 0, .w = @intCast(mepo.win_w), .h = @intCast(mepo.win_h) },
        .Fill,
    );
    try blit_tiles_all(
        mepo,
        .{
            .x = 0,
            .y = 0,
            .w = @intCast(mepo.win_w),
            .h = @intCast(mepo.win_h),
        },
        p.get(p.pref.zoom).u,
    );
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

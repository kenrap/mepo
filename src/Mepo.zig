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
download_bar: bool = false,
drag: bool = false,
drag_scale: u8 = 1,
fonts: [50]*sdl.TTF_Font,
help: bool = false,
keybindings_table: std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8),
lat: f64 = 0,
lon: f64 = 0,
pin_active: ?[]const u8 = null,
pin_table: std.hash_map.StringHashMap(types.Pin),
redraw_requested_at_ms_ticks: ?u32 = null,
renderer: *sdl.SDL_Renderer,
signals_table: std.array_hash_map.AutoArrayHashMap(u6, []const u8),
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

pub fn blit_tiles_all(mepo: *@This(), vpx: i32, vpy: i32, vpw: u32, vph: u32, zoom: u8) !void {
    const begx = vpx - config.Tsize;
    const begy = vpy - config.Tsize;
    const endx = vpx + @intCast(i32, vpw) + config.Tsize;
    const endy = vpy + @intCast(i32, vph) + config.Tsize;

    var tilex: i32 = @intCast(i32, @divFloor(begx, config.Tsize));
    var tiley: i32 = @intCast(i32, @divFloor(begy, config.Tsize));

    var x = begx;
    while (x < endx) {
        var y = begy;
        tiley = @intCast(i32, @divFloor(begy, config.Tsize));
        while (y < endy) {
            if (tilex >= 0 and tiley >= 0 and tilex <= std.math.pow(u32, 2, zoom) - 1 and tiley <= std.math.pow(u32, 2, zoom) - 1) {
                try mepo.blit_tile_surface(@intCast(u32, tilex), @intCast(u32, tiley), zoom, vpx, vpy);
                try mepo.blit_tile_text(@intCast(u32, tilex), @intCast(u32, tiley), zoom, vpx, vpy);
            } else {
                utildbg.log("Blit wont blit for neg x={d} y={d}\n", .{ tilex, tiley });
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

    switch (try mepo.tile_cache.tile_retrieve(.{ .x = tile_x, .y = tile_y, .z = zoom })) {
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

pub fn blit_tile_surface(mepo: *@This(), tile_x: u32, tile_y: u32, zoom: u8, x_off: i32, y_off: i32) !void {
    const rect_dest = sdl.SDL_Rect{
        .x = @intCast(i32, tile_x * config.Tsize) - x_off,
        .y = @intCast(i32, tile_y * config.Tsize) - y_off,
        .w = config.Tsize,
        .h = config.Tsize,
    };

    var rect_intersect: sdl.SDL_Rect = undefined;

    if (@intToEnum(sdl.SDL_bool, sdl.SDL_FALSE) == sdl.SDL_IntersectRect(&rect_dest, &sdl.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = @intCast(c_int, mepo.win_w),
        .h = @intCast(c_int, mepo.win_h),
    }, &rect_intersect)) return;

    const rect_src = sdl.SDL_Rect{
        .x = if (rect_intersect.x > rect_dest.x) rect_dest.w - rect_intersect.w else 0,
        .y = if (rect_intersect.y > rect_dest.y) rect_dest.h - rect_intersect.h else 0,
        .w = rect_intersect.w,
        .h = rect_intersect.h,
    };

    switch (try mepo.tile_cache.tile_retrieve(.{ .x = tile_x, .y = tile_y, .z = zoom })) {
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
    }
}

fn blit_debug(mepo: *@This()) !void {
    if (mepo.debug_vars) {
        const bbox = mepo.bounding_box();
        try mepo.blit_multiline_text(
            0x000000,
            null,
            .{},
            5,
            5,
            null,
            "x: {d}\ny: {d}\nz: {d}\nlat: {d:.5}\nlon: {d:.5}\nbbox: {d:.3}x{d:.3}km",
            .{
                mepo.get_x(),
                mepo.get_y(),
                mepo.zoom,
                mepo.lat,
                mepo.lon,
                utilconversion.distance_km_haversine(
                    bbox.topleft_lat,
                    bbox.topleft_lon,
                    bbox.bottomright_lat,
                    bbox.topleft_lon,
                ),
                utilconversion.distance_km_haversine(
                    bbox.topleft_lat,
                    bbox.topleft_lon,
                    bbox.topleft_lat,
                    bbox.bottomright_lon,
                ),
            },
        );
    }

    if (mepo.debug_message_enabled and mepo.debug_message != null) {
        try mepo.blit_multiline_text(
            0xff0000,
            null,
            .{ .align_x = .Right },
            @intCast(i32, mepo.win_w - 5),
            5,
            null,
            "DEBUG: {s}",
            .{mepo.debug_message.?},
        );
    }
}

fn blit_pins(mepo: *@This()) errors.SDLError!void {
    var it = mepo.pin_table.iterator();
    while (it.next()) |item| {
        const x = -1 * (mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), 2) - utilconversion.lon_to_px_x(item.value_ptr.lon, mepo.zoom));
        const y = -1 * (mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), 2) - utilconversion.lat_to_px_y(item.value_ptr.lat, mepo.zoom));
        const size: i32 = 10;
        const color_value: u24 = if (mepo.pin_active != null and std.mem.eql(u8, item.key_ptr.*, mepo.pin_active.?))
            0xff0000
        else
            0x000000;

        if (x < 0 or x > mepo.win_w or y < 0 or y > mepo.win_h)
            continue;

        try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = color_value }, sdl.SDL_Rect{
            .x = x - @divTrunc(size, 2),
            .y = y - @divTrunc(size, 2),
            .w = size,
            .h = size,
        }, .Fill);
    }
}

fn blit_pin_active_text(mepo: *@This()) !void {
    if (mepo.pin_active == null) return;

    const overlay_height = 70;
    const y_off: i32 = if (mepo.download_bar) 20 else 0;
    const y_pos = @intCast(i32, mepo.win_h) - overlay_height - y_off;

    try utilsdl.sdl_renderer_rect(mepo.renderer, .{ .value = 0xffff00, .opacity = 120 }, sdl.SDL_Rect{
        .x = 0,
        .y = y_pos,
        .w = @intCast(i32, mepo.win_w),
        .h = 200,
    }, .Fill);

    if (mepo.pin_table.get(mepo.pin_active.?)) |pin| {
        try mepo.blit_multiline_text(
            0x000000,
            null,
            .{ .align_y = .Center, .h = overlay_height },
            5,
            y_pos,
            null,
            \\Pin: {s}
            \\lat: {d:.5}
            \\lon: {d:.5}
            \\dist: {d:.2}km away
        ,
            .{
                pin.name,
                pin.lat,
                pin.lon,
                utilconversion.distance_km_haversine(mepo.lat, mepo.lon, pin.lat, pin.lon),
            },
        );
        try mepo.blit_multiline_text(
            0x000000,
            null,
            .{ .align_y = .Center, .align_x = .Right, .w = mepo.win_w, .h = overlay_height },
            0,
            y_pos,
            null,
            "{d}",
            .{mepo.pin_table.count()},
        );
    }
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
    try mepo.blit_multiline_text(
        0x000000,
        null,
        .{},
        5,
        @intCast(i32, mepo.win_h) - 20 + 3,
        null,
        "Tiles Queued: {d} / Downloading: {d} / Memory: {d}",
        .{ mepo.tile_cache.queue_lifo.count(), mepo.tile_cache.n_current_transfers, mepo.tile_cache.texture_map.count() },
    );
}

fn blit_help(mepo: *@This()) !void {
    if (!mepo.help) return;

    var msg = msg: {
        var acc = std.ArrayList([]const u8).init(mepo.allocator);
        defer acc.deinit();
        defer for (acc.items) |item| mepo.allocator.free(item);

        var it = mepo.keybindings_table.iterator();

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
        \\mepo - Development version
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
        mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), 2),
        mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), 2),
        mepo.win_w,
        mepo.win_h,
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
        mepo.drag = false;
        return .None;
    } else if (e.button.button == sdl.SDL_BUTTON_LEFT) {
        mepo.drag = true;
    }
    return .None;
}

fn event_mousebuttonup(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (!mepo.within_touch_bounds(e.button.x, e.button.y)) {
        mepo.drag = false;
        return .None;
    } else if (e.button.button == sdl.SDL_BUTTON_LEFT) {
        mepo.drag = false;
        if (e.button.clicks == 1) {
            return .Redraw;
        } else if (e.button.clicks == 2) {
            zoom_relative(mepo, 1);
            mepo.redraw_requested_at_ms_ticks = sdl.SDL_GetTicks();
        } else if (e.button.clicks > 2) {
            // E.g. (-2) since actually button.clicks 2 will have processed
            // with (1)... is there a way to make these evts exclusive?
            zoom_relative(mepo, -2);
            return .Redraw;
        }
    } else if (e.button.button == sdl.SDL_BUTTON_RIGHT) {
        zoom_relative(mepo, -1);
        return .Redraw;
    }
    return .None;
}

fn event_mousemotion(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.drag and mepo.within_touch_bounds(e.motion.x, e.motion.y)) {
        mepo.set_x(mepo.get_x() - (e.motion.xrel * mepo.drag_scale));
        mepo.set_y(mepo.get_y() - (e.motion.yrel * mepo.drag_scale));
        return .Drag;
    } else {
        mepo.drag = false;
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
    if (mepo.keybindings_table.get(.{
        .keycode = @intToEnum(sdl.SDL_KeyCode, @intCast(c_int, e.key.keysym.sym)),
        .keymod = @intToEnum(sdl.SDL_Keymod, @intCast(c_int, e.key.keysym.mod)),
    })) |run_expression| {
        utildbg.log("Got keybindings table function {s}\n", .{run_expression});
        mepo.mepolang_execute(run_expression) catch unreachable;
        return .Redraw;
    }
    return .None;
}

fn event_signal(mepo: *@This(), signal: u6) types.Pending {
    if (mepo.signals_table.get(signal)) |run_expression| {
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

    for (try utilstrings.statementize(&arena.allocator, mepolang_text)) |statement| {
        utildbg.log("Executing statment: {s}\n", .{statement});
        if (statement.len < 1) continue;

        // Lookup and run fn
        if (FnTable.get(statement[0])) |func| {
            const args: [types.MepoFnNargs]types.MepoArg = try utilmepolang.mepolang_argize(&arena.allocator, statement[1..statement.len]);
            utildbg.log("Running API function for: {s} requested by mepolang input statement: {s}\n", .{ statement[0], statement });
            func(mepo, args) catch |mepolang_err| {
                utildbg.log("Error running API function for: {s}: {}\n", .{ statement[0], mepolang_err });
            };
        } else {
            utildbg.log("Requested API function {s} but that's not registered in ftable\n", .{statement[0]});
        }
    }
}

pub fn sdl_event_loop(mepo: *@This()) !void {
    var pending: types.Pending = .None;
    var e: sdl.SDL_Event = undefined;

    while (true) {
        // Redraw
        const has_pending_motion_events = (sdl.SDL_bool.SDL_TRUE == sdl.SDL_HasEvent(@enumToInt(sdl.SDL_EventType.SDL_MOUSEMOTION)));
        const has_pending_redraw_ms = (mepo.redraw_requested_at_ms_ticks != null and sdl.SDL_GetTicks() > mepo.redraw_requested_at_ms_ticks.? + @intCast(u32, config.ClickTimeoutMs));
        if (has_pending_redraw_ms or
            (!has_pending_motion_events and pending == .Drag) or
            pending == .Redraw)
        {
            try blit(mepo);
            mepo.redraw_requested_at_ms_ticks = null;
        }

        // Process SDL events
        if (sdl.SDL_WaitEventTimeout(&e, config.ClickTimeoutMs) > 0) {
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
                sdl.TTF_RenderText_Solid(mepo.fonts[font_size], @ptrCast([*c]const u8, line_sentinel_terminated), (types.Color{ .value = color }).sdl()),
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

pub fn update_debug_message(mepo: *@This(), new_msg: []const u8) !void {
    if (mepo.debug_message) |dbg_msg| {
        mepo.allocator.free(dbg_msg);
    }
    mepo.debug_message = try mepo.allocator.dupe(u8, new_msg);
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

            const font_dat = @embedFile("../assets/terminus.ttf");
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
        .keybindings_table = std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8).init(allocator),
        .pin_table = std.hash_map.StringHashMap(types.Pin).init(allocator),
        .renderer = try utilsdl.errorcheck_ptr(sdl.SDL_Renderer, sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_SOFTWARE)),
        .signals_table = std.array_hash_map.AutoArrayHashMap(u6, []const u8).init(allocator),
        .tile_cache = tile_cache,
        .window = window,
    });

    // Set renderer for tile cache
    tile_cache.set_renderer(instance.renderer);

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

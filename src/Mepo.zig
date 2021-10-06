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
const _fn_table = @import("./api/_fn_table.zig");
const zoom_relative = @import("./api/zoom_relative.zig").zoom_relative;

allocator: *std.mem.Allocator,
window: *sdl.SDL_Window,
renderer: *sdl.SDL_Renderer,
tile_cache: *TileCache,
font: *sdl.TTF_Font,
lon: f64,
lat: f64,
w: u32,
h: u32,
mouse_pending_last_time: ?u32,
mouse_pending_n_taps: ?u32,
crosshair_size: u32,
crosshair_on: bool,
debug_tiles: bool,
debug_global: bool,
download_bar: bool,
zoom: u8,
drag: bool,
pin_active: ?[]const u8,
pin_table: std.hash_map.StringHashMap(types.Pin),
fn_table: std.array_hash_map.StringArrayHashMap(types.MepoFn),
keybindings_table: std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8),

fn blit_crosshair(mepo: *@This()) errors.SDLError!void {
    if (!mepo.crosshair_on) return;

    try utilsdl.sdl_renderer_set_draw_color(mepo.renderer, 0x000000);
    if (0 != sdl.SDL_RenderDrawLine(
        mepo.renderer,
        @intCast(c_int, mepo.w / 2 - (mepo.crosshair_size / 2)),
        @intCast(c_int, mepo.h / 2),
        @intCast(c_int, mepo.w / 2 + (mepo.crosshair_size / 2)),
        @intCast(c_int, mepo.h / 2),
    )) {
        return errors.SDLError.RenderDrawLine;
    } else if (0 != sdl.SDL_RenderDrawLine(
        mepo.renderer,
        @intCast(c_int, mepo.w / 2),
        @intCast(c_int, mepo.h / 2 - (mepo.crosshair_size / 2)),
        @intCast(c_int, mepo.w / 2),
        @intCast(c_int, mepo.h / 2 + (mepo.crosshair_size / 2)),
    )) {
        return errors.SDLError.RenderDrawLine;
    }
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
        @intCast(i32, tile_x * config.Tsize) - x_off,
        @intCast(i32, tile_y * config.Tsize) - y_off,
        config.Tsize,
        config.Tsize,
        "tx: {d}\nty: {d}\ndl: {d}/{d}",
        .{ tile_x, tile_y, dl_now, dl_total },
    );
}

pub fn blit_tile_surface(mepo: *@This(), tile_x: u32, tile_y: u32, zoom: u8, x_off: i32, y_off: i32) !void {
    const dest = sdl.SDL_Rect{
        .x = @intCast(i32, tile_x * config.Tsize) - x_off,
        .y = @intCast(i32, tile_y * config.Tsize) - y_off,
        .w = config.Tsize,
        .h = config.Tsize,
    };

    switch (try mepo.tile_cache.tile_retrieve(.{ .x = tile_x, .y = tile_y, .z = zoom })) {
        .texture => |text| {
            if (sdl.SDL_RenderCopy(mepo.renderer, text, null, &dest) > 0) {
                return errors.SDLError.BlitSurface;
            }
        },
        .queued_position => |queued_position| {
            try utilsdl.sdl_renderer_fill_rect(mepo.renderer, 0xebebeb, dest);
            try mepo.blit_multiline_text(
                dest.x,
                dest.y,
                @intCast(u32, dest.w),
                @intCast(u32, dest.h),
                "{d}",
                .{queued_position},
            );
        },
        .transfer_datum => {
            try utilsdl.sdl_renderer_fill_rect(mepo.renderer, 0x006400, dest);
        },
    }
}

fn blit_global_text(mepo: *@This()) !void {
    if (!mepo.debug_global) return;

    try mepo.blit_multiline_text(
        5,
        5,
        mepo.w,
        mepo.h,
        "x: {d}\ny: {d}\nz: {d}\nlat: {d}\nlon: {d}",
        .{ mepo.get_x(), mepo.get_y(), mepo.zoom, mepo.lat, mepo.lon },
    );
}

fn blit_pins(mepo: *@This()) errors.SDLError!void {
    var it = mepo.pin_table.iterator();
    while (it.next()) |item| {
        const x = -1 * (mepo.get_x() - @divTrunc(@intCast(i32, mepo.w), 2) - utilconversion.lon_to_px_x(item.value_ptr.lon, mepo.zoom));
        const y = -1 * (mepo.get_y() - @divTrunc(@intCast(i32, mepo.h), 2) - utilconversion.lat_to_px_y(item.value_ptr.lat, mepo.zoom));
        const size: i32 = 10;
        const color: u24 = if (mepo.pin_active != null and std.mem.eql(u8, item.key_ptr.*, mepo.pin_active.?))
            0xff0000
        else
            0x000000;

        if (x < 0 or x > mepo.w or y < 0 or y > mepo.h)
            continue;

        try utilsdl.sdl_renderer_fill_rect(mepo.renderer, color, sdl.SDL_Rect{
            .x = x - @divTrunc(size, 2),
            .y = y - @divTrunc(size, 2),
            .w = size,
            .h = size,
        });
    }
}

fn blit_pin_active_text(mepo: *@This()) !void {
    if (mepo.pin_active == null) return;

    try utilsdl.sdl_renderer_fill_rect(mepo.renderer, 0xffff00, sdl.SDL_Rect{
        .x = 0,
        .y = @intCast(i32, mepo.h) - (18 * 3) - 6,
        .w = @intCast(i32, mepo.w),
        .h = 200,
    });

    const pin_opt = mepo.pin_table.get(mepo.pin_active.?);

    if (pin_opt) |pin| {
        try mepo.blit_multiline_text(
            5,
            @intCast(i32, mepo.h) - (18 * 3),
            mepo.w,
            mepo.h,
            "Pin: {s}\nlat: {d}\nlon: {d}\n",
            .{ pin.name, pin.lat, pin.lon },
        );
        try mepo.blit_multiline_text(
            @intCast(i32, mepo.w) - 20,
            @intCast(i32, mepo.h) - (18 * 3),
            mepo.w,
            mepo.h,
            "{d}p",
            .{mepo.pin_table.count()},
        );
    }
}

fn blit_download_bar(mepo: *@This()) !void {
    if (!mepo.download_bar) return;

    try utilsdl.sdl_renderer_fill_rect(mepo.renderer, 0xffffff, sdl.SDL_Rect{
        .x = 0,
        .y = @intCast(i32, mepo.h) - 20,
        .w = @intCast(i32, mepo.w),
        .h = 200,
    });
    try utilsdl.sdl_renderer_fill_rect(mepo.renderer, 0x00000, sdl.SDL_Rect{
        .x = 0,
        .y = @intCast(i32, mepo.h) - 20,
        .w = @intCast(i32, mepo.w),
        .h = 1,
    });
    try mepo.blit_multiline_text(
        5,
        @intCast(i32, mepo.h) - 20 + 3,
        mepo.w,
        mepo.h,
        "Queued: {d} / Currently downloading: {d} / Cached Tiles: {d}",
        .{ mepo.tile_cache.queue_lifo.count(), mepo.tile_cache.n_current_transfers, mepo.tile_cache.texture_map.count() },
    );
}

pub fn blit(mepo: *@This()) !void {
    try utilsdl.sdl_renderer_fill_rect(mepo.renderer, 0xffffff, null);
    try blit_tiles_all(
        mepo,
        mepo.get_x() - @divTrunc(@intCast(i32, mepo.w), 2),
        mepo.get_y() - @divTrunc(@intCast(i32, mepo.h), 2),
        mepo.w,
        mepo.h,
        mepo.zoom,
    );
    try mepo.blit_global_text();
    try mepo.blit_pins();
    try mepo.blit_pin_active_text();
    try mepo.blit_crosshair();
    try mepo.blit_download_bar();

    sdl.SDL_RenderPresent(mepo.renderer);

    // Update title
    const title = try std.fmt.allocPrintZ(mepo.allocator, "mepo - {d} lat, {d} lon", .{ mepo.lat, mepo.lon });
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
    if (e.button.button == sdl.SDL_BUTTON_LEFT) {
        mepo.drag = true;
    }
    return .None;
}

fn event_mousebuttonup(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (e.button.button == sdl.SDL_BUTTON_LEFT) {
        mepo.drag = false;
        mepo.mouse_pending_last_time = sdl.SDL_GetTicks();
        if (mepo.mouse_pending_n_taps == null) {
            mepo.mouse_pending_n_taps = 1;
        } else {
            mepo.mouse_pending_n_taps.? += 1;
        }
        _ = sdl.SDL_AddTimer(201, mouse_timeout, null);
    } else if (e.button.button == sdl.SDL_BUTTON_RIGHT) {
        zoom_relative(mepo, -1);
        return .Redraw;
    }
    return .None;
}

fn event_mousemotion(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.drag) {
        mepo.set_x(mepo.get_x() - e.motion.xrel);
        mepo.set_y(mepo.get_y() - e.motion.yrel);
        return .Drag;
    }
    return .None;
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
        utildbg.log("Got table function {s}\n", .{run_expression});
        mepo.mepolang_execute(run_expression) catch unreachable;
        return .Redraw;
    }
    return .None;
}

fn event_windowevent(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    switch (@intToEnum(sdl.SDL_WindowEventID, e.window.event)) {
        .SDL_WINDOWEVENT_RESIZED => {
            mepo.w = @intCast(u32, e.window.data1);
            mepo.h = @intCast(u32, e.window.data2);
            //mepo.center_on_coords(old_lat, old_lon);
        },
        else => {},
    }
    return .Redraw;
}

fn event_quit(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    @panic("Quit");
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
        if (mepo.fn_table.get(statement[0])) |func| {
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

fn mouse_timeout(interval: u32, v: ?*c_void) callconv(.C) u32 {
    _ = utilsdl.sdl_push_resize_event();
    return 0;
}

pub fn sdl_event_loop(mepo: *@This()) !void {
    var pending: types.Pending = .None;
    var e: sdl.SDL_Event = undefined;

    while (true) {
        // Dispatch double/triple taps
        if (mepo.mouse_pending_n_taps != null) {
            if (sdl.SDL_GetTicks() > mepo.mouse_pending_last_time.? + @intCast(u32, 200)) {
                if (mepo.mouse_pending_n_taps.? == 2) {
                    zoom_relative(mepo, 1);
                } else if (mepo.mouse_pending_n_taps.? > 2) {
                    zoom_relative(mepo, -1);
                }
                pending = .Redraw;
                mepo.mouse_pending_n_taps = null;
                mepo.mouse_pending_last_time = null;
            }
        }

        // Redraw
        const has_pending_motion_events = (sdl.SDL_bool.SDL_TRUE == sdl.SDL_HasEvent(@enumToInt(sdl.SDL_EventType.SDL_MOUSEMOTION)));
        if ((!has_pending_motion_events and pending == .Drag) or
            pending == .Redraw)
        {
            try blit(mepo);
        }

        // Process SDL events
        if (sdl.SDL_WaitEvent(&e) > 0) {
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
    }
}

pub fn blit_multiline_text(mepo: *@This(), x: i32, y: i32, w: u32, h: u32, comptime fmt_string: []const u8, args: anytype) !void {
    var msg = try std.fmt.allocPrintZ(mepo.allocator, fmt_string, args);
    defer mepo.allocator.free(msg);

    // TODO: Implement clipping based on passed w/h
    const line_height = @floatToInt(u32, config.FontSize * 1.25);

    var dest_rect = sdl.SDL_Rect{ .x = x, .y = y, .w = undefined, .h = undefined };
    var start: usize = 0;
    var current: usize = 0;
    while (current < msg.len) : (current += 1) {
        if (msg[current] == '\n' or current == msg.len - 1) {
            msg[current] = 0;
            const text_surf: ?*sdl.SDL_Surface = sdl.TTF_RenderText_Solid(mepo.font, @ptrCast([*c]const u8, &msg[start]), utilsdl.u24_to_sdl_color(0x00000));
            defer sdl.SDL_FreeSurface(text_surf);
            if (text_surf != null) {
                if (sdl.SDL_CreateTextureFromSurface(mepo.renderer, text_surf)) |text| {
                    defer sdl.SDL_DestroyTexture(text);
                    dest_rect.w = text_surf.?.w;
                    dest_rect.h = text_surf.?.h;
                    if (sdl.SDL_RenderCopy(mepo.renderer, text, null, &dest_rect) > 0) {
                        return errors.SDLError.BlitSurface;
                    }
                } else {
                    return errors.SDLError.CreateTextureFromSurface;
                }
            }
            start = current + 1;
            dest_rect.y += line_height;
        }
    }
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

pub fn sighandle_terminate(arg: c_int) callconv(.C) void {
    utildbg.log("Graceful shutdown via signal: {}\n", .{arg});
    sdl.SDL_VideoQuit();
    sdl.SDL_Quit();
    std.os.exit(0);
}

pub fn init(tile_cache: *TileCache, cfg_opt: ?[]const u8) anyerror!@This() {
    var font_opt: ?*sdl.TTF_Font = null;
    var window: ?*sdl.SDL_Window = null;

    // Initialize video, create window
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) < 0) {
        return errors.SDLError.Init;
    } else {
        window = sdl.SDL_CreateWindow(
            "mepo",
            sdl.SDL_WINDOWPOS_UNDEFINED,
            sdl.SDL_WINDOWPOS_UNDEFINED,
            config.InitWindowW,
            config.InitWindowH,
            sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE,
        );
        if (window == null) {
            return errors.SDLError.CreateWindow;
        }
    }

    var renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_SOFTWARE);
    if (renderer == null) {
        return errors.SDLError.CreateRenderer;
    }

    // Initialize TTF, load font
    if (sdl.TTF_Init() == -1) {
        utildbg.log("Failed to load lazy font! SDL_ttf Error: {s}\n", .{sdl.TTF_GetError()});
        return errors.SDLError.TTF_Init;
    } else {
        const font = @embedFile("../assets/terminus.ttf");
        font_opt = sdl.TTF_OpenFontRW(sdl.SDL_RWFromConstMem(@ptrCast(*const c_void, &font[0]), font.len), 1, config.FontSize);
        if (font_opt == null) {
            utildbg.log("Failed to load lazy font! SDL_ttf Error: {s}\n", .{sdl.TTF_GetError()});
            return errors.SDLError.OpenFontRW;
        }
    }

    // Create struct
    var instance = @as(@This(), .{
        .allocator = std.heap.c_allocator,
        .mouse_pending_last_time = null,
        .mouse_pending_n_taps = null,
        .window = window.?,
        .renderer = renderer.?,
        .font = font_opt.?,
        .lat = 0,
        .lon = 0,
        .w = config.InitWindowW,
        .h = config.InitWindowH,
        .zoom = 14,
        .drag = false,
        .debug_tiles = false,
        .debug_global = false,
        .download_bar = false,
        .crosshair_size = 10,
        .crosshair_on = true,
        .tile_cache = tile_cache,
        .pin_table = std.hash_map.StringHashMap(types.Pin).init(std.heap.c_allocator),
        .pin_active = null,
        .fn_table = try _fn_table.generate_fn_table(),
        .keybindings_table = std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8).init(std.heap.c_allocator),
    });

    tile_cache.set_renderer(instance.renderer);

    try instance.pin_table.ensureCapacity(100000);

    // Run config (base and then user provided STDIN)
    try instance.mepolang_execute(config.DefaultBaseConfig);
    if (cfg_opt) |cfg| {
        try instance.mepolang_execute(cfg);
    }

    // Setup TERM/INT signals
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

    return instance;
}

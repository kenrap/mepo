const std = @import("std");
const sdl = @import("./sdlshim.zig");
const conversionutil = @import("./util/conversionutil.zig");
const types = @import("./types.zig");
const config = @import("./config.zig");
const errors = @import("./errors.zig");
const TileCache = @import("./TileCache.zig");
const parseutil = @import("util/parseutil.zig");
const stringsutil = @import("util/stringsutil.zig");
const sdlutil = @import("util/sdlutil.zig");
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

    try mepo.renderer_set_draw_color(0x000000);
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
                std.debug.warn("Blit wont blit for neg x={d} y={d}\n", .{ tilex, tiley });
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
    const screen = sdl.SDL_GetWindowSurface(mepo.window);

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
    var screen = sdl.SDL_GetWindowSurface(mepo.window);
    const dest = &sdl.SDL_Rect{
        .x = @intCast(i32, tile_x * config.Tsize) - x_off,
        .y = @intCast(i32, tile_y * config.Tsize) - y_off,
        .w = config.Tsize,
        .h = config.Tsize,
    };

    switch (try mepo.tile_cache.tile_retrieve(.{ .x = tile_x, .y = tile_y, .z = zoom })) {
        .texture => |text| {
            if (sdl.SDL_RenderCopy(mepo.renderer, text, null, dest) > 0) {
                return errors.SDLError.BlitSurface;
            }
        },
        .queued_position => |queued_position| {
            try mepo.renderer_set_draw_color(0xebebeb);
            _ = sdl.SDL_RenderFillRect(mepo.renderer, dest);
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
            try mepo.renderer_set_draw_color(0x006400);
            _ = sdl.SDL_RenderFillRect(mepo.renderer, dest);
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
        var x = -1 * (mepo.get_x() - @divTrunc(@intCast(i32, mepo.w), 2) - conversionutil.lon_to_px_x(item.value_ptr.lon, mepo.zoom));
        var y = -1 * (mepo.get_y() - @divTrunc(@intCast(i32, mepo.h), 2) - conversionutil.lat_to_px_y(item.value_ptr.lat, mepo.zoom));

        var size: i32 = 10;
        try mepo.renderer_set_draw_color(if (mepo.pin_active != null and std.mem.eql(u8, item.key_ptr.*, mepo.pin_active.?))
            0xff0000
        else
            0x000000);
        _ = sdl.SDL_RenderFillRect(mepo.renderer, &sdl.SDL_Rect{
            .x = x - @divTrunc(size, 2),
            .y = y - @divTrunc(size, 2),
            .w = size,
            .h = size,
        });
    }
}

fn blit_pin_active_text(mepo: *@This()) !void {
    if (mepo.pin_active == null) return;

    try mepo.renderer_set_draw_color(0xffff00);
    if (0 != sdl.SDL_RenderFillRect(mepo.renderer, &sdl.SDL_Rect{
        .x = 0,
        .y = @intCast(i32, mepo.h) - (18 * 3) - 6,
        .w = @intCast(i32, mepo.w),
        .h = 200,
    })) {
        return error.Todo;
    }

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

    try mepo.renderer_set_draw_color(0xffffff);
    _ = sdl.SDL_RenderFillRect(mepo.renderer, &sdl.SDL_Rect{
        .x = 0,
        .y = @intCast(i32, mepo.h) - 20,
        .w = @intCast(i32, mepo.w),
        .h = 200,
    });

    try mepo.renderer_set_draw_color(0x000000);
    _ = sdl.SDL_RenderFillRect(mepo.renderer, &sdl.SDL_Rect{
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
        .{ mepo.tile_cache.queue_map.count(), mepo.tile_cache.n_current_transfers, mepo.tile_cache.texture_map.count() },
    );
}

pub fn blit(mepo: *@This()) !void {
    try mepo.renderer_set_draw_color(0xffffff);
    if (sdl.SDL_RenderFillRect(mepo.renderer, null) != 0) {
        std.debug.warn("Fill fail {s}", .{sdl.SDL_GetError()});
        return errors.SDLError.FillRect;
    }

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
    var title = try std.fmt.allocPrintZ(mepo.allocator, "mepo - {d} lat, {d} lon", .{ mepo.lat, mepo.lon });
    defer mepo.allocator.free(title);
    _ = sdl.SDL_SetWindowTitle(mepo.window, title);
}

pub fn mepolang_argize(allocator: *std.mem.Allocator, tokens: []const []const u8) ![types.MepoFnNargs]types.MepoArg {
    var args_i: usize = 0;
    var args: [types.MepoFnNargs]types.MepoArg = undefined;
    var i: usize = 0;
    var bracket_start_i: usize = undefined;
    var bracket_nest_n: usize = 0;

    for (tokens) |tok| {
        if (tok[0] == '[' and tok.len == 1) bracket_nest_n += 1;
        if (tok[0] == ']' and tok.len == 1) bracket_nest_n -= 1;

        if (bracket_nest_n == 1 and tok[0] == '[' and tok.len == 1) {
            bracket_start_i = i;
        } else if (bracket_nest_n == 0 and tok[0] == ']' and tok.len == 1) {
            args[args_i] = .{ .Text = try std.mem.joinZ(allocator, " ", tokens[bracket_start_i + 1 .. i]) };
            args_i += 1;
        } else if (bracket_nest_n >= 1) {
            // nop
        } else if ((tok[0] == '-' and tok.len > 1) or (tok[0] >= '0' and tok[0] <= '9')) {
            args[args_i] = .{ .Number = try std.fmt.parseFloat(f64, tok) };
            args_i += 1;
        } else {
            args[args_i] = .{ .Text = try std.fmt.allocPrintZ(allocator, "{s}", .{tok}) };
            args_i += 1;
        }
        i += 1;
    }

    return args;
}

pub fn mepolang_execute(mepo: *@This(), mepolang_text: []const u8) !void {
    for (try stringsutil.statementize(mepolang_text)) |statement| {
        std.debug.warn("Executing statment: {s}\n", .{statement});
        if (statement.len < 1) continue;

        // Lookup and run fn
        if (mepo.fn_table.get(statement[0])) |func| {
            var args: [types.MepoFnNargs]types.MepoArg = try mepolang_argize(mepo.allocator, statement[1..statement.len]);
            std.debug.warn("Running API function for: {s} requested by mepolang input statement: {s}\n", .{ statement[0], statement });
            try func(mepo, args);
        } else {
            std.debug.warn("Requested API function {s} but that's not registered in ftable\n", .{statement[0]});
        }
    }
}

fn mouse_timeout(interval: u32, v: ?*c_void) callconv(.C) u32 {
    _ = sdlutil.sdl_push_resize_event();
    return 0;
}

pub fn sdl_event_loop(mepo: *@This()) !void {
    var pending: enum { None, Redraw, Drag } = .None;
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
            pending = .None;

            switch (@intToEnum(sdl.SDL_EventType, @intCast(c_int, e.type))) {
                .SDL_MULTIGESTURE => {
                    const threshold = 0.005;

                    if (e.mgesture.dDist > threshold) {
                        zoom_relative(mepo, 1);
                        pending = .Redraw;
                    }
                    if (e.mgesture.dDist < -threshold) {
                        zoom_relative(mepo, -1);
                        pending = .Redraw;
                    }
                },
                .SDL_MOUSEBUTTONDOWN => {
                    if (e.button.button == sdl.SDL_BUTTON_LEFT) {
                        mepo.drag = true;
                    }
                },
                .SDL_MOUSEBUTTONUP => {
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
                        pending = .Redraw;
                    }
                },
                .SDL_MOUSEMOTION => {
                    if (mepo.drag) {
                        mepo.set_x(mepo.get_x() - e.motion.xrel);
                        mepo.set_y(mepo.get_y() - e.motion.yrel);
                        pending = .Drag;
                    }
                },
                .SDL_MOUSEWHEEL => {
                    zoom_relative(mepo, e.wheel.y);
                    pending = .Redraw;
                },
                .SDL_KEYUP => {
                    if (mepo.keybindings_table.get(.{
                        .keycode = @intToEnum(sdl.SDL_KeyCode, @intCast(c_int, e.key.keysym.sym)),
                        .keymod = @intToEnum(sdl.SDL_Keymod, @intCast(c_int, e.key.keysym.mod)),
                    })) |run_expression| {
                        std.debug.warn("Got table function {s}\n", .{run_expression});
                        try mepo.mepolang_execute(run_expression);
                        pending = .Redraw;
                    }
                },
                .SDL_WINDOWEVENT => {
                    switch (@intToEnum(sdl.SDL_WindowEventID, e.window.event)) {
                        .SDL_WINDOWEVENT_RESIZED => {
                            mepo.w = @intCast(u32, e.window.data1);
                            mepo.h = @intCast(u32, e.window.data2);
                            //mepo.center_on_coords(old_lat, old_lon);
                        },
                        else => {},
                    }
                    pending = .Redraw;
                },
                .SDL_QUIT => {
                    std.debug.warn("WINDOW EVENT\n", .{});
                    return;
                },
                else => {},
            }
        }
    }
}

pub fn renderer_set_draw_color(mepo: *@This(), val: u24) !void {
    const color = u24_to_sdl_color(val);
    if (0 != sdl.SDL_SetRenderDrawColor(mepo.renderer, color.r, color.g, color.b, sdl.SDL_ALPHA_OPAQUE)) {
        return errors.SDLError.RenderDrawColor;
    }
}

pub fn u24_to_sdl_color(val: u24) sdl.SDL_Color {
    return .{
        .r = @intCast(u8, val >> 16),
        .g = @intCast(u8, val >> 8 & 0xff),
        .b = @intCast(u8, val & 0xff),
        .a = sdl.SDL_ALPHA_OPAQUE,
    };
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
            var text_surf: ?*sdl.SDL_Surface = sdl.TTF_RenderText_Solid(mepo.font, @ptrCast([*c]const u8, &msg[start]), u24_to_sdl_color(0x00000));
            if (text_surf != null) {
                if (sdl.SDL_CreateTextureFromSurface(mepo.renderer, text_surf)) |text| {
                    dest_rect.w = text_surf.?.w;
                    dest_rect.h = text_surf.?.h;
                    if (sdl.SDL_RenderCopy(mepo.renderer, text, null, &dest_rect) > 0) {
                        return errors.SDLError.BlitSurface;
                    }
                } else {
                    return error.Fail;
                }
            }
            start = current + 1;
            dest_rect.y += line_height;
        }
    }
}

pub fn get_x(mepo: *@This()) i32 {
    return conversionutil.lon_to_px_x(mepo.lon, mepo.zoom);
}

pub fn get_y(mepo: *@This()) i32 {
    return conversionutil.lat_to_px_y(mepo.lat, mepo.zoom);
}

pub fn set_x(mepo: *@This(), x: i32) void {
    mepo.lon = conversionutil.px_x_to_lon(x, mepo.zoom);
}

pub fn set_y(mepo: *@This(), y: i32) void {
    mepo.lat = conversionutil.px_y_to_lat(y, mepo.zoom);
}

pub fn sighandle_terminate(arg: c_int) callconv(.C) void {
    std.debug.warn("Graceful shutdown via signal: {}\n", .{arg});
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
        std.debug.warn("Failed to load lazy font! SDL_ttf Error: {s}\n", .{sdl.TTF_GetError()});
        return errors.SDLError.TTF_Init;
    } else {
        const font = @embedFile("../assets/terminus.ttf");
        font_opt = sdl.TTF_OpenFontRW(sdl.SDL_RWFromConstMem(@ptrCast(*const c_void, &font[0]), font.len), 1, config.FontSize);
        if (font_opt == null) {
            std.debug.warn("Failed to load lazy font! SDL_ttf Error: {s}\n", .{sdl.TTF_GetError()});
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

test "mepolang_argize" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const spec = struct {
        input: []const []const u8,
        expect: []const types.MepoArg,
    };

    var specs = [_]spec{
        .{
            // Standard check to make sure text / numbers argized properly
            .input = &[_][]const u8{ "arga", "22.2" },
            .expect = &[_]types.MepoArg{
                types.MepoArg{ .Text = "arga" },
                types.MepoArg{ .Number = 22.2 },
            },
        },
        .{
            // Numbers check (negative, postive)
            .input = &[_][]const u8{ "-22.4", "2747.2716" },
            .expect = &[_]types.MepoArg{
                types.MepoArg{ .Number = -22.4 },
                types.MepoArg{
                    .Number = 2747.2716,
                },
            },
        },
        .{
            // Ensure argizer never parses past 1st set of string, e.g. nested []
            // should just tokenize as single arg proc
            .input = &[_][]const u8{ "foo", "bar", "[", "baz", "bill", "]", "dill", "jill" },
            .expect = &[_]types.MepoArg{ types.MepoArg{ .Text = "foo" }, types.MepoArg{ .Text = "bar" }, types.MepoArg{ .Text = "baz bill" }, types.MepoArg{ .Text = "dill" } },
        },
    };

    for (specs) |s| {
        const result = try mepolang_argize(&arena.allocator, s.input[0..]);
        for (s.expect) |_, i| {
            try std.testing.expectEqual(@TypeOf(s.expect[i]), @TypeOf(result[i]));
            switch (result[i]) {
                .Number => try std.testing.expectEqual(s.expect[i].Number, result[i].Number),
                .Text => try std.testing.expectEqualSlices(u8, s.expect[i].Text, result[i].Text),
            }
        }
    }
}

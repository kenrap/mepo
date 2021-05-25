const std = @import("std");
const sdl = @import("./sdlshim.zig");
const conversionutil = @import("./util/conversionutil.zig");
const types = @import("./types.zig");
const config = @import("./config.zig");
const TileCache = @import("./TileCache.zig");
const parseutil = @import("util/parseutil.zig");
const stringsutil = @import("util/stringsutil.zig");
const sdlutil = @import("util/sdlutil.zig");
const _fn_table = @import("./api/_fn_table.zig");
const zoom_relative = @import("./api/zoom_relative.zig").zoom_relative;

window: *sdl.SDL_Window,
renderer: *sdl.SDL_Renderer,
tile_cache: *TileCache,
font: *sdl.TTF_Font,
x: i32,
y: i32,
w: u32,
h: u32,
demokey: ?u8,
mouse_pending_last_time: ?u32,
mouse_pending_n_taps: ?u32,
crosshair_size: u32,
crosshair_on: bool,
debug_tiles: bool,
debug_global: bool,
zoom: u8,
drag: bool,
pin_active: ?[]const u8,
pin_table: std.array_hash_map.StringArrayHashMap(types.Pin),
fn_table: std.array_hash_map.StringArrayHashMap(types.MepoFn),
keybindings_table: std.array_hash_map.AutoArrayHashMap(sdl.SDL_KeyCode, []const u8),

fn blit_crosshair(fmap: *@This()) !void {
    if (!fmap.crosshair_on) return;

    var r = sdl.SDL_CreateSoftwareRenderer(sdl.SDL_GetWindowSurface(fmap.window));

    if (0 != sdl.SDL_SetRenderDrawColor(r, 0, 0, 0, 255)) {
      return error.Utoh;
    } else if (0 != sdl.SDL_RenderDrawLine(r, 
      @intCast(c_int, fmap.w / 2 - (fmap.crosshair_size / 2)), 
      @intCast(c_int, fmap.h / 2), 
      @intCast(c_int, fmap.w / 2 + (fmap.crosshair_size / 2)), 
      @intCast(c_int, fmap.h / 2), 
    )) {
      return error.Utoh;
    } else if (0 != sdl.SDL_RenderDrawLine(r, 
      @intCast(c_int, fmap.w / 2), 
      @intCast(c_int, fmap.h / 2 - (fmap.crosshair_size / 2)), 
      @intCast(c_int, fmap.w / 2), 
      @intCast(c_int, fmap.h / 2 + (fmap.crosshair_size / 2)), 
    )) {
      return error.Utoh;
    }
}

pub fn blit_tiles_all(fmap: *@This(), vpx: i32, vpy: i32, vpw: u32, vph: u32, zoom: u8) !void {
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
                try fmap.blit_tile_surface(@intCast(u32, tilex), @intCast(u32, tiley), zoom, vpx, vpy);
                try fmap.blit_tile_text(@intCast(u32, tilex), @intCast(u32, tiley), zoom, vpx, vpy);
            } else {
                std.debug.warn("Blit wont blit for neg x={} y={}\n", .{ tilex, tiley });
            }
            y += config.Tsize;
            tiley += 1;
        }
        x += config.Tsize;
        tilex += 1;
    }
}

pub fn blit_tile_text(fmap: *@This(), tile_x: u32, tile_y: u32, zoom: u8, x_off: i32, y_off: i32) !void {
    if (!fmap.debug_tiles) return;
    var dl_now: c_long = 0;
    var dl_total: c_long = 0;

    var tile_data = try fmap.tile_cache.tile_retrieve(sdl.SDL_GetWindowSurface(fmap.window).*.format, .{ .x = tile_x, .y = tile_y, .z = zoom });
    if (tile_data.transfer_datum) |transfer_datum| {
        if (transfer_datum.progress_dl_now) |dln| {
            dl_now = dln;
        }
        if (transfer_datum.progress_dl_total) |dlt| {
            dl_total = dlt;
        }
    }

    try fmap.blit_multiline_text(
      @intCast(i32, tile_x * 256) - x_off,
      @intCast(i32, tile_y * 256) - y_off,
      256,
      256,
      "tx: {}\nty: {}\ndl: {}/{}",
      .{ tile_x, tile_y, dl_now, dl_total }
    );
}

pub fn blit_tile_surface(fmap: *@This(), tile_x: u32, tile_y: u32, zoom: u8, x_off: i32, y_off: i32) !void {
    var screen = sdl.SDL_GetWindowSurface(fmap.window);
    var tile_data = try fmap.tile_cache.tile_retrieve(screen.*.format, .{ .x = tile_x, .y = tile_y, .z = zoom });
    if (tile_data.surface) |surf| {
        if (sdl.SDL_BlitSurface(@ptrCast([*c]sdl.SDL_Surface, surf), null, screen, &sdl.SDL_Rect{
          .x = @intCast(i32, tile_x * 256) - x_off,
          .y = @intCast(i32, tile_y * 256) - y_off,
          .w = 256,
          .h = 256
        }) > 0) {
            return error.BlitError;
        }
    } else {
        // Blit background color tile?

        //var surf = sdl.SDL_CreateRGBSurfaceWithFormat(256, 256, 256, 32, pixel_format.format);
        //if (sdl.SDL_FillRect(surf, null, sdl.SDL_MapRGB(pixel_format, 255, 0, 255)) != 0) {
        //    std.debug.warn("Fill fail {s}", .{sdl.SDL_GetError()});
        //    return error.FillFail;
        //}
    }
}

fn blit_global_text(fmap: *@This()) !void {
    if (!fmap.debug_global) return;

    const lat = conversionutil.px_to_lat(fmap.y, fmap.zoom);
    const lon = conversionutil.px_to_lon(fmap.x, fmap.zoom);
    const surf = try fmap.blit_multiline_text(
      5,
      5,
      fmap.w,
      fmap.h,
      "x: {}\ny: {}\nz: {}\nlat: {d}\nlon: {d}",
      .{ fmap.x, fmap.y, fmap.zoom, lat, lon }
    );
}

fn blit_pins(fmap: *@This()) !void {
    var surf = sdl.SDL_GetWindowSurface(fmap.window);
    var r = sdl.SDL_CreateSoftwareRenderer(surf);

    if (0 != sdl.SDL_SetRenderDrawColor(r, 0, 0, 0, 255)) {
      return error.Utoh;
    } 

    for (fmap.pin_table.items()) |item| {
      var x = -1 * (fmap.x - @divTrunc(@intCast(i32, fmap.w), 2) - conversionutil.lon_to_px(item.value.lon, fmap.zoom));
      var y = -1 * (fmap.y - @divTrunc(@intCast(i32, fmap.h), 2) - conversionutil.lat_to_px(item.value.lat, fmap.zoom));

      var size : i32 = 10;
      _ = sdl.SDL_FillRect(sdl.SDL_GetWindowSurface(fmap.window), &sdl.SDL_Rect{
        .x = x - @divTrunc(size, 2), 
        .y = y - @divTrunc(size, 2), 
        .w = size,
        .h = size,
      }, sdl.SDL_MapRGBA(surf.*.format, if (fmap.pin_active != null and std.mem.eql(u8, item.key, fmap.pin_active.?)) 255 else 0, 0, 0, 255));
   }    
}

fn blit_pin_active_text(fmap: *@This()) !void {
    if (fmap.pin_active == null) return;

    _ = sdl.SDL_FillRect(sdl.SDL_GetWindowSurface(fmap.window), &sdl.SDL_Rect{
      .x = 0,
      .y = @intCast(i32, fmap.h) - (18 * 3) - 6,
      .w = @intCast(i32, fmap.w),
      .h = 200,
    }, sdl.SDL_MapRGBA(sdl.SDL_GetWindowSurface(fmap.window).*.format, 255, 255, 0, 0));
    
    const pin_opt = fmap.pin_table.get(fmap.pin_active.?);

    if (pin_opt) |pin| {
      _ = try fmap.blit_multiline_text(
        5,
        @intCast(i32, fmap.h) - (18 * 3),
        fmap.w,
        fmap.h,
        "Pin: {}\nlat: {}\nlon: {}\n",
        .{ pin.name, pin.lat, pin.lon }
      );

      _ = try fmap.blit_multiline_text(
        @intCast(i32, fmap.w) - 20,
        @intCast(i32, fmap.h) - (18 * 3),
        fmap.w,
        fmap.h,
        "{d}p",
        .{ fmap.pin_table.items().len }
      );

    }
}

fn blit_demokeyoverlay(fmap: *@This()) !void {
    if (fmap.demokey == null) return;
    _ = sdl.SDL_FillRect(sdl.SDL_GetWindowSurface(fmap.window), &sdl.SDL_Rect{
      .x = @intCast(i32, fmap.w) - 50,
      .y = 10,
      .w = 30,
      .h = 30,
    }, sdl.SDL_MapRGBA(sdl.SDL_GetWindowSurface(fmap.window).*.format, 255, 255, 255, 0));
    
    _ = try fmap.blit_multiline_text(
      @intCast(i32, fmap.w) - 50 + 10,
      15,
      30,
      30,
      "{c}p",
      .{fmap.demokey}
    );
}

fn draw_circle(renderer: *sdl.SDL_Renderer, radius: usize, center_x: i32, center_y: i32) void {
   var x : c_int = @intCast(c_int, radius);
   var y : c_int = 0;
   var err : c_int = 0;
   while (x >= y) {
     _ = sdl.SDL_RenderDrawPoint(renderer, center_x + x, center_y + y);
     _ = sdl.SDL_RenderDrawPoint(renderer, center_x + y, center_y + x);
     _ = sdl.SDL_RenderDrawPoint(renderer, center_x - y, center_y + x);
     _ = sdl.SDL_RenderDrawPoint(renderer, center_x - x, center_y + y);
     _ = sdl.SDL_RenderDrawPoint(renderer, center_x - x, center_y - y);
     _ = sdl.SDL_RenderDrawPoint(renderer, center_x - y, center_y - x);
     _ = sdl.SDL_RenderDrawPoint(renderer, center_x + y, center_y - x);
     _ = sdl.SDL_RenderDrawPoint(renderer, center_x + x, center_y - y);
     
     if (err <= 0) {
       y += 1;
       err += 2*y + 1;
    }
 
    if (err > 0) { 
      x -= 1;
      err -= 2*x + 1;
    }
   }
}

pub fn blit(fmap: *@This()) !void {
    var screen = sdl.SDL_GetWindowSurface(fmap.window);
    if (sdl.SDL_FillRect(screen, null, sdl.SDL_MapRGB(screen.*.format, 255, 255, 255)) != 0) {
        std.debug.warn("Fill fail {s}", .{sdl.SDL_GetError()});
        return error.FillFail;
    }

    try blit_tiles_all(fmap, fmap.x - @divTrunc(@intCast(i32, fmap.w), 2), fmap.y - @divTrunc(@intCast(i32, fmap.h), 2), fmap.w, fmap.h, fmap.zoom);
    try blit_global_text(fmap);
    try blit_pins(fmap);
    try blit_pin_active_text(fmap);
    try blit_crosshair(fmap);
    try blit_demokeyoverlay(fmap);

    if (sdl.SDL_UpdateWindowSurface(fmap.window) > 0) {
        return error.UpdateWindowError;
    }


    // Update title
    const lat = conversionutil.px_to_lat(fmap.y, fmap.zoom);
    const lon = conversionutil.px_to_lon(fmap.x, fmap.zoom);
    var title = try std.fmt.allocPrintZ(std.heap.c_allocator, "mepo - {d} lat, {d} lon", .{lat, lon});
    _ = sdl.SDL_SetWindowTitle(fmap.window, title);

}

pub fn mepolang_argize(tokens: [][]const u8) ![5]types.MepoArg {
    var args_i: usize = 0;
    var args: [5]types.MepoArg = undefined;
    var i: usize = 0;
    var start_bracket: ?usize = null;

    for (tokens) |tok| {
        if (tok[0] == '[' and tok.len == 1) {
            start_bracket = i;
        } else if (tok[0] == ']' and tok.len == 1) {
            args[args_i] = .{ .Text = try std.mem.joinZ(std.heap.c_allocator, " ", tokens[start_bracket.? + 1 .. i]) };
            args_i += 1;
        } else if (start_bracket != null) {
            // nop
        } else if ((tok[0] == '-' and tok.len > 1) or (tok[0] >= '0' and tok[0] <= '9')) {
            args[i] = .{ .Number = try std.fmt.parseFloat(f64, tok) };
            args_i += 1;
        } else {
            args[i] = .{ .Text = try std.fmt.allocPrintZ(std.heap.c_allocator, "{}", .{tok}) };
            args_i += 1;
        }
        i += 1;
    }
    return args;
}

pub fn mepolang_execute(fmap: *@This(), mepolang_text: []const u8) !void {
    for (try stringsutil.statementize(mepolang_text)) |statement| {
        std.debug.warn("Executing statment: {}\n", .{statement});
        if (statement.len < 1) continue;

        // Lookup and run fn
        if (fmap.fn_table.get(statement[0])) |func| {
            var args: [5]types.MepoArg = try mepolang_argize(statement[1..statement.len]);
            std.debug.warn("Running API function: {} with args {}\n", .{ func, args });
            try func(fmap, args);
        } else {
            std.debug.warn("Requested API function {} but that's not registered in ftable\n", .{statement[0]});
        }
    }
}

fn mouse_timeout(interval: u32, v: ?*c_void) callconv(.C) u32 {
  _ = sdlutil.sdl_push_resize_event() catch 0 ;
  return 0;
}


pub fn sdl_event_loop(fmap: *@This()) !void {
    var e: sdl.SDL_Event = undefined;
    while (true) {

        // Dispatch double/triple taps
        if (fmap.mouse_pending_n_taps != null) {
          if (sdl.SDL_GetTicks() > fmap.mouse_pending_last_time.? + @intCast(u32, 200)) {
            if (fmap.mouse_pending_n_taps.? == 2) {
              zoom_relative(fmap, 1);
            } else if (fmap.mouse_pending_n_taps.? > 2) {
              zoom_relative(fmap, -1);
            }
            try blit(fmap);
            fmap.mouse_pending_n_taps = null;
            fmap.mouse_pending_last_time = null;
          }
        }

        // Process SDL events
        if (sdl.SDL_WaitEvent(&e) > 0) {
            switch (@intToEnum(sdl.SDL_EventType, @intCast(c_int, e.type))) {
              .SDL_MULTIGESTURE => {
                  if (e.mgesture.dDist > 0.02) {
                    fmap.zoom +=1;
                    try blit(fmap);
                  }
                        if (e.mgesture.dDist < -0.02) {
                        fmap.zoom +=1;
                                                try blit(fmap);
                        }
                        },
                .SDL_MOUSEBUTTONDOWN => {
                    if (e.button.button == sdl.SDL_BUTTON_LEFT) {
                        fmap.drag = true;
                    }
                },
                .SDL_MOUSEBUTTONUP => {
                    if (e.button.button == sdl.SDL_BUTTON_LEFT) {
                      fmap.drag = false;
                      fmap.mouse_pending_last_time = sdl.SDL_GetTicks();
                      if (fmap.mouse_pending_n_taps == null) {
                        fmap.mouse_pending_n_taps = 1;
                      } else {
                        fmap.mouse_pending_n_taps.? += 1;
                      }
                      _ = sdl.SDL_AddTimer(201, mouse_timeout, null);
                    } else if (e.button.button == sdl.SDL_BUTTON_RIGHT) {
                        zoom_relative(fmap, -1);
                    }
                },
                .SDL_MOUSEMOTION => {
                    if (fmap.drag) {
                        fmap.x -= e.motion.xrel;
                        fmap.y -= e.motion.yrel;
                        try blit(fmap);
                    }
                },
                .SDL_MOUSEWHEEL => {
                    zoom_relative(fmap, e.wheel.y);
                    try blit(fmap);
                },
                .SDL_KEYDOWN => {
                    if (fmap.keybindings_table.get(@intToEnum(sdl.SDL_KeyCode, @intCast(c_int, e.key.keysym.sym)))) |run_expression| {
                        fmap.demokey = sdl.SDL_GetKeyName(e.key.keysym.sym)[0];
                        std.debug.warn("Got table function {}", .{run_expression});
                        try fmap.mepolang_execute(run_expression);
                        try blit(fmap);
                    }
                },
                .SDL_WINDOWEVENT => {
                    switch (@intToEnum(sdl.SDL_WindowEventID, e.window.event)) {
                        .SDL_WINDOWEVENT_EXPOSED => {
                            try blit(fmap);
                        },
                        .SDL_WINDOWEVENT_RESIZED => {
                            var old_lat = conversionutil.px_to_lat(fmap.y, fmap.zoom);
                            var old_lon = conversionutil.px_to_lon(fmap.x, fmap.zoom);
                            fmap.w = @intCast(u32, e.window.data1);
                            fmap.h = @intCast(u32, e.window.data2);
                            //fmap.center_on_coords(old_lat, old_lon);
                            try blit(fmap);
                        },
                        else => {
                            std.debug.warn("Unhandled winevet\n", .{});
                        },
                    }
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

pub fn blit_multiline_text(fmap: *@This(), x: i32, y: i32, w: u32, h: u32, comptime fmt_string: []const u8, args: anytype) !void {
    var msg = try std.fmt.allocPrintZ(std.heap.page_allocator, fmt_string, args);
    defer std.heap.page_allocator.free(msg);

    var dest_rect = sdl.SDL_Rect{
      .x = x,
      .y = y,
      .w = @intCast(c_int, w),
      .h = @intCast(c_int, h),
    };

    const line_height = 16;
    var start : usize = 0;
    var current : usize = 0;
    while (current < msg.len) : (current += 1) {
      if (msg[current] == '\n' or current == msg.len - 1 ) {
        msg[current] = 0;
        var text_surf: ?*sdl.SDL_Surface = sdl.TTF_RenderText_Solid(fmap.font, @ptrCast([*c]const u8, &msg[start]), .{ .r = 0, .g = 0, .b = 0, .a = 1 });
        if (text_surf != null) {
          if (sdl.SDL_BlitSurface(text_surf.?, null, sdl.SDL_GetWindowSurface(fmap.window), &dest_rect) > 0) {
                return error.BlitError;
          }
        }
        start = current + 1;
        dest_rect.y += line_height;
      }
    }
}

pub fn init(tile_cache: *TileCache, cfg: []const u8) anyerror!@This() {
    var font_opt: ?*sdl.TTF_Font = null;
    var window: ?*sdl.SDL_Window = null;

    // Initialize video, create window
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) < 0) {
        return error.VideoInitializationFailed;
    } else {
        window = sdl.SDL_CreateWindow("mepo", sdl.SDL_WINDOWPOS_UNDEFINED, sdl.SDL_WINDOWPOS_UNDEFINED, config.InitWindowW, config.InitWindowH, sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE);
        if (window == null) {
            return error.WindowCreateFailed;
        }
    }

    var renderer = sdl.SDL_CreateRenderer(window, -1, 0);
    if (renderer == null) {
      return error.FailedToCreateRenderer;
    }

    // Initialize TTF, load font
    if (sdl.TTF_Init() == -1) {
        std.debug.warn("Failed to load lazy font! SDL_ttf Error: {s}\n", .{sdl.TTF_GetError()});
        return error.InitTTFFail;
    } else {
        font_opt = sdl.TTF_OpenFont("assets/terminus.ttf", 14);
        if (font_opt == null) {
            std.debug.warn("Failed to load lazy font! SDL_ttf Error: {s}\n", .{sdl.TTF_GetError()});
            return error.LoadFontFail;
        }
    }

    // Create struct
    var instance = @as(@This(), .{
        .mouse_pending_last_time = null,
        .mouse_pending_n_taps = null,
        .window = window.?,
        .renderer = renderer.?,
        .font = font_opt.?,
        .x = 0,
        .y = 0,
        .w = config.InitWindowW,
        .h = config.InitWindowH,
        .zoom = config.StartZoom,
        .drag = false,
        .debug_tiles = false,
        .debug_global = false,
        .demokey = null,
        .crosshair_size = 10,
        .crosshair_on = true,
        .tile_cache = tile_cache,
        .pin_table = std.array_hash_map.StringArrayHashMap(types.Pin).init(std.heap.c_allocator),
        .pin_active = null,
        .fn_table = try _fn_table.generate_fn_table(),
        .keybindings_table = std.array_hash_map.AutoArrayHashMap(sdl.SDL_KeyCode, []const u8).init(std.heap.c_allocator),
    });

    try instance.pin_table.ensureCapacity(100000);

    // Run config (base and then user provided STDIN)
    try instance.mepolang_execute(config.DefaultBaseConfig);
    try instance.mepolang_execute(cfg);

    return instance;
}

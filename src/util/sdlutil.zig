const sdl = @import("../sdlshim.zig");
const errors = @import("../errors.zig");

pub fn sdl_push_resize_event() void {
    var sdlevent: sdl.SDL_Event = undefined;
    sdlevent.type = sdl.SDL_WINDOWEVENT;
    sdlevent.window.event = sdl.SDL_WINDOWEVENT_EXPOSED;
    _ = sdl.SDL_PushEvent(&sdlevent);
}

pub fn sdl_renderer_set_draw_color(renderer: *sdl.SDL_Renderer, val: u24) errors.SDLError!void {
    const color = u24_to_sdl_color(val);
    if (0 != sdl.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, sdl.SDL_ALPHA_OPAQUE)) {
        return errors.SDLError.RenderDrawColor;
    }
}

pub fn sdl_renderer_fill_rect(renderer: *sdl.SDL_Renderer, color: u24, rect: ?sdl.SDL_Rect) errors.SDLError!void {
    const rect_ptr: ?*const sdl.SDL_Rect = rect_ptr: {
        if (rect != null) {
            break :rect_ptr &rect.?;
        } else {
            break :rect_ptr null;
        }
    };

    try sdl_renderer_set_draw_color(renderer, color);

    if (0 != sdl.SDL_RenderFillRect(renderer, rect_ptr)) {
        return errors.SDLError.RenderFillRect;
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

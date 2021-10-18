const sdl = @import("../sdlshim.zig");
const types = @import("../types.zig");
const errors = @import("../errors.zig");
const utildbg = @import("./utildbg.zig");

const RectOpt = enum { Draw, Fill };

pub fn sdl_push_resize_event() void {
    var sdlevent: sdl.SDL_Event = undefined;
    sdlevent.type = sdl.SDL_WINDOWEVENT;
    sdlevent.window.event = sdl.SDL_WINDOWEVENT_EXPOSED;
    _ = sdl.SDL_PushEvent(&sdlevent);
}

pub fn sdl_renderer_set_draw_color(renderer: *sdl.SDL_Renderer, color: types.Color) errors.SDLError!void {
    var sdl_color = color.sdl();
    const blend_mode = if (sdl_color.a != sdl.SDL_ALPHA_OPAQUE) sdl.SDL_BLENDMODE_ADD else sdl.SDL_BLENDMODE_NONE;
    try errorcheck(sdl.SDL_SetRenderDrawBlendMode(renderer, @intToEnum(sdl.SDL_BlendMode, blend_mode)));
    try errorcheck(sdl.SDL_SetRenderDrawColor(renderer, sdl_color.r, sdl_color.g, sdl_color.b, color.opacity));
}

pub fn sdl_renderer_rect(renderer: *sdl.SDL_Renderer, color: types.Color, rect: ?sdl.SDL_Rect, rect_opt: RectOpt) errors.SDLError!void {
    const rect_ptr: ?*const sdl.SDL_Rect = rect_ptr: {
        if (rect != null) {
            break :rect_ptr &rect.?;
        } else {
            break :rect_ptr null;
        }
    };
    try sdl_renderer_set_draw_color(renderer, color);
    if (rect_opt == .Draw) {
        try errorcheck(sdl.SDL_RenderDrawRect(renderer, rect_ptr));
    } else {
        try errorcheck(sdl.SDL_RenderFillRect(renderer, rect_ptr));
    }
}

pub fn sdl_renderer_draw_rect(renderer: *sdl.SDL_Renderer, color: types.Color, rect: ?sdl.SDL_Rect) errors.SDLError!void {
    const rect_ptr: ?*const sdl.SDL_Rect = rect_ptr: {
        if (rect != null) {
            break :rect_ptr &rect.?;
        } else {
            break :rect_ptr null;
        }
    };
    try sdl_renderer_set_draw_color(renderer, color, opacity);
    try errorcheck(sdl.SDL_RenderDrawRect(renderer, rect_ptr));
}

pub fn errorcheck(return_value: c_int) errors.SDLError!void {
    if (return_value != 0) {
        utildbg.log("SDL Error: {s}\n", .{sdl.SDL_GetError()});
        return errors.SDLError.GenericSDLError;
    }
}

pub fn errorcheck_ptr(comptime return_type: type, pointer: ?*return_type) errors.SDLError!*return_type {
    if (pointer) |p| {
        return p;
    } else {
        utildbg.log("SDL Error: {s}\n", .{sdl.SDL_GetError()});
        return errors.SDLError.GenericSDLError;
    }
}

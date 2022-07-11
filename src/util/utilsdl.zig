const sdl = @import("../sdlshim.zig");
const types = @import("../types.zig");
const errors = @import("../errors.zig");
const utildbg = @import("./utildbg.zig");
const RectOpt = enum { Draw, Fill };

pub fn sdl_usereventtype(event_type: enum { Mepolang, Signal }) u32 {
    // E.g. static local, via var in struct
    const static_local = struct {
        var sdl_user_event_0: ?u32 = null;
        var sdl_user_event_1: ?u32 = null;
    };
    if (static_local.sdl_user_event_0 == null) static_local.sdl_user_event_0 = sdl.SDL_RegisterEvents(1);
    if (static_local.sdl_user_event_1 == null) static_local.sdl_user_event_1 = sdl.SDL_RegisterEvents(1);
    return switch (event_type) {
        .Mepolang => static_local.sdl_user_event_0.?,
        .Signal => static_local.sdl_user_event_1.?,
    };
}

pub fn sdl_push_event_resize() void {
    // E.g. Used internally by blit as basically manual refresh
    const pending_drag = sdl.SDL_HasEvent(sdl.SDL_MOUSEMOTION) == sdl.SDL_TRUE;
    const pending_redraw = sdl.SDL_HasEvent(sdl.SDL_WINDOWEVENT) == sdl.SDL_TRUE;
    if (pending_drag or pending_redraw) return;

    var sdlevent: sdl.SDL_Event = undefined;
    sdlevent.type = sdl.SDL_WINDOWEVENT;
    sdlevent.window.event = sdl.SDL_WINDOWEVENT_EXPOSED;
    errorcheck(sdl.SDL_PushEvent(&sdlevent)) catch |err| {
        utildbg.log("Error pushing resize event to SDL queue: {s}\n", .{err});
    };
}

pub fn sdl_push_event_mepolang_execution(mepolang_text: [:0]const u8) void {
    var sdlevent: sdl.SDL_Event = undefined;
    const str_ptr = &mepolang_text[0];
    sdlevent.type = sdl_usereventtype(.Mepolang);
    sdlevent.user.code = 0;
    sdlevent.user.data1 = @intToPtr([*c]u8, @ptrToInt(str_ptr));
    sdlevent.user.data2 = null;
    errorcheck(sdl.SDL_PushEvent(&sdlevent)) catch |err| {
        utildbg.log("Error pushing mepolang event to SDL queue: {s}\n", .{err});
    };
}

pub fn sdl_push_event_signal(signal: c_int) callconv(.C) void {
    var sdlevent: sdl.SDL_Event = undefined;
    sdlevent.type = sdl_usereventtype(.Signal);
    sdlevent.user.code = signal;
    _ = sdl.SDL_PushEvent(&sdlevent);
}

pub fn sdl_renderer_set_draw_color(renderer: *sdl.SDL_Renderer, color: types.Color) errors.SDLError!void {
    var sdl_color = color.to_sdl();
    const blend_mode = if (sdl_color.a != sdl.SDL_ALPHA_OPAQUE) sdl.SDL_BLENDMODE_ADD else sdl.SDL_BLENDMODE_NONE;
    try errorcheck(sdl.SDL_SetRenderDrawBlendMode(renderer, @intCast(c_uint, blend_mode)));
    try errorcheck(sdl.SDL_SetRenderDrawColor(renderer, sdl_color.r, sdl_color.g, sdl_color.b, color.opacity));
}

pub fn sdl_renderer_rect(renderer: *sdl.SDL_Renderer, color: types.Color, rect: sdl.SDL_Rect, rect_opt: RectOpt) errors.SDLError!void {
    try sdl_renderer_set_draw_color(renderer, color);
    if (rect_opt == .Draw) {
        try errorcheck(sdl.SDL_RenderDrawRect(renderer, &rect));
    } else {
        try errorcheck(sdl.SDL_RenderFillRect(renderer, &rect));
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
    try sdl_renderer_set_draw_color(renderer, color);
    try errorcheck(sdl.SDL_RenderDrawRect(renderer, rect_ptr));
}

pub fn sdl_keymod_to_str(c: u32) *const [3]u8 {
    return switch (c) {
        sdl.KMOD_LCTRL | sdl.KMOD_RCTRL => "  s",
        sdl.KMOD_LSHIFT | sdl.KMOD_RSHIFT => "  s",
        sdl.KMOD_LSHIFT | sdl.KMOD_RSHIFT | sdl.KMOD_LCTRL | sdl.KMOD_RCTRL => " cs",
        sdl.KMOD_LALT | sdl.KMOD_RALT => "  a",
        else => "   ",
    };
}

pub fn errorcheck(return_value: c_int) errors.SDLError!void {
    if (return_value < 0) {
        utildbg.log("SDL Error: {s}\n", .{sdl.SDL_GetError()});
        sdl.SDL_ClearError();
        return errors.SDLError.GenericSDLError;
    }
}

pub fn errorcheck_ptr(comptime return_type: type, pointer: ?*return_type) errors.SDLError!*return_type {
    if (pointer) |p| {
        return p;
    } else {
        utildbg.log("SDL Error: {s}\n", .{sdl.SDL_GetError()});
        sdl.SDL_ClearError();
        return errors.SDLError.GenericSDLError;
    }
}

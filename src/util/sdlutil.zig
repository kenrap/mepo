const sdl = @import("../sdlshim.zig");

pub fn sdl_push_resize_event() void {
    var sdlevent: sdl.SDL_Event = undefined;
    sdlevent.type = sdl.SDL_WINDOWEVENT;
    sdlevent.window.event = sdl.SDL_WINDOWEVENT_EXPOSED;
    _ = sdl.SDL_PushEvent(&sdlevent);
}

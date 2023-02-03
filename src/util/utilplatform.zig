const sdl = @import("../sdlshim.zig");
const std = @import("std");

pub fn supports_osk() bool {
    const has_sdl_osk = sdl.SDL_HasScreenKeyboardSupport() == sdl.SDL_TRUE;
    const xdg_desktop = xdg_session_desktop();
    return has_sdl_osk or xdg_desktop == .Phosh or xdg_desktop == .Plamo;
}

pub fn xdg_session_desktop() enum { Phosh, Plamo, Unknown } {
    var env_session_desktop: []const u8 = "unknown";
    if (std.os.getenv("XDG_SESSION_DESKTOP")) |v| {
        env_session_desktop = v;
    }

    if (std.mem.eql(u8, env_session_desktop, "phosh")) {
        return .Phosh;
    } else if (std.mem.eql(u8, env_session_desktop, "plasma-mobile")) {
        return .Plamo;
    } else {
        return .Unknown;
    }
}

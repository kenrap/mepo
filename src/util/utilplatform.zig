const sdl = @import("../sdlshim.zig");
const std = @import("std");

pub fn supports_osk() bool {
    const has_sdl_osk = sdl.SDL_HasScreenKeyboardSupport() == sdl.SDL_TRUE;
    return has_sdl_osk or is_phosh();
}

pub fn is_phosh() bool {
    var env_session_desktop: []const u8 = "unknown";
    if (std.os.getenv("XDG_SESSION_DESKTOP")) |v| {
        env_session_desktop = v;
    }
    return std.mem.eql(u8, env_session_desktop, "phosh");
}

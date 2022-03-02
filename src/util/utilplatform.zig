const sdl = @import("../sdlshim.zig");
const std = @import("std");

pub fn supports_osk() bool {
    var env_session_desktop: []const u8 = "unknown";
    if (std.os.getenv("XDG_SESSION_DESKTOP")) |v| {
        env_session_desktop = v;
    }

    const is_phosh = std.mem.eql(u8, env_session_desktop, "phosh");
    const has_sdl_osk = sdl.SDL_HasScreenKeyboardSupport() == sdl.SDL_bool.SDL_TRUE;
    return has_sdl_osk or is_phosh;
}

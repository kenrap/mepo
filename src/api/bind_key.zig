const Fmap = @import("../Fmap.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");


pub fn f_bind_key(fmap: *Fmap, args: [5]types.MepoArg) !void {
    const key = args[0].Text;
    const expression = args[1].Text;
    try bind_key(fmap, key, expression);
}

pub fn bind_key(fmap: *Fmap, key: [:0]const u8, expression: []const u8) !void {
    std.debug.warn("Binding key: {} to expression {}\n", .{key, expression});

    const keycode = sdl.SDL_GetKeyFromName(key);
    if (keycode == sdl.SDLK_UNKNOWN) {
      return error.UnableToLookupKeyName;
    }

    // TODO: Check if overwriting?

    try fmap.keybindings_table.put(
      @intToEnum(sdl.SDL_KeyCode, @intCast(c_int, keycode)),
      expression
    );
}

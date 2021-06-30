const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");


pub fn f_bind_key(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const key = args[0].Text;
    const expression = args[1].Text;
    try bind_key(mepo, key, expression);
}

pub fn bind_key(mepo: *Mepo, key: [:0]const u8, expression: []const u8) !void {
    std.debug.warn("Binding key: {s} to expression {s}\n", .{key, expression});

    const keycode = sdl.SDL_GetKeyFromName(key);
    if (keycode == sdl.SDLK_UNKNOWN) {
      return error.UnableToLookupKeyName;
    }

    // TODO: Check if overwriting?

    try mepo.keybindings_table.put(
      .{
        .keymod = null,
        .keycode = @intToEnum(sdl.SDL_KeyCode, @intCast(c_int, keycode)),
      },
      expression
    );
}

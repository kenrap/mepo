const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub fn f_bind_key(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const modifier = args[0].Text;
    const key = args[1].Text;
    const expression = args[2].Text;
    try bind_key(mepo, modifier, key, expression);
}

fn bind_key(mepo: *Mepo, mod_str: [:0]const u8, key_str: [:0]const u8, expression: []const u8) !void {
    utildbg.log("Binding key: mod={s} code={s} to expression {s}\n", .{ mod_str, key_str, expression });

    // Keymod
    const keymod = m: {
        var modifier = sdl.KMOD_NONE;
        for (mod_str) |character| {
            if (character == 'c') {
                modifier = modifier | sdl.KMOD_LCTRL;
            } else if (character == 's') {
                modifier = modifier | sdl.KMOD_LSHIFT;
            } else if (character == 'a') {
                modifier = modifier | sdl.KMOD_LALT;
            }
        }
        break :m modifier;
    };

    // Keycode
    const keycode = sdl.SDL_GetKeyFromName(key_str);
    if (keycode == sdl.SDLK_UNKNOWN) {
        return error.UnableToLookupKeyName;
    }

    const expression_mepo_allocated = try std.fmt.allocPrint(mepo.allocator, "{s}", .{expression});
    try mepo.keybindings_table.put(.{
        .keymod = @intToEnum(sdl.SDL_Keymod, keymod),
        .keycode = @intToEnum(sdl.SDL_KeyCode, @intCast(c_int, keycode)),
    }, expression_mepo_allocated);
}

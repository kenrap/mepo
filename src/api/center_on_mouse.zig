const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");

pub fn f_center_on_mouse(mepo: *Mepo, args: [5]types.MepoArg) !void {
    var x : c_int = undefined;
    var y : c_int = undefined;
    _ = sdl.SDL_GetMouseState(&x, &y);

    mepo.x += (@intCast(i32, x) - @intCast(i32, (mepo.w / 2)));
    mepo.y += (@intCast(i32, y) - @intCast(i32, (mepo.h / 2)));
}

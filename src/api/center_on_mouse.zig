const Fmap = @import("../Fmap.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");

pub fn f_center_on_mouse(fmap: *Fmap, args: [5]types.MepoArg) !void {
    var x : c_int = undefined;
    var y : c_int = undefined;
    _ = sdl.SDL_GetMouseState(&x, &y);

    fmap.x += (@intCast(i32, x) - @intCast(i32, (fmap.w / 2)));
    fmap.y += (@intCast(i32, y) - @intCast(i32, (fmap.h / 2)));
}

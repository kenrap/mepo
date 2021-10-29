const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");

pub fn f_center_on_mouse(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    var x: c_int = undefined;
    var y: c_int = undefined;
    _ = sdl.SDL_GetMouseState(&x, &y);

    mepo.set_x(x + (@intCast(i32, mepo.get_x()) - @intCast(i32, (mepo.win_w / 2))));
    mepo.set_y(y + (@intCast(i32, mepo.get_y()) - @intCast(i32, (mepo.win_h / 2))));
}

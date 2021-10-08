const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");

pub fn f_quit(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    Mepo.graceful_terminate();
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_quit(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    @panic("Quit");
}

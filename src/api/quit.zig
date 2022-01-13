const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_quit(_: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    Mepo.graceful_terminate();
}

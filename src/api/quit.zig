const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "quit",
    .desc = "Quit the application",
    .args = (&[_]types.MepoFnSpecArg{})[0..],
    .execute = execute,
};

fn execute(_: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    Mepo.graceful_terminate();
}

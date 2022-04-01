const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilarg = @import("../util/utilarg.zig");

pub const spec = .{
    .args = (&[_]types.MepoArgTag{ .Number, .Number })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const lat = args[0].Number;
    const lon = args[1].Number;
    mepo.lon = lon;
    mepo.lat = lat;
}

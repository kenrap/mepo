const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const utilprefs = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "prefinc",
    .desc = "Increase or decrease a preference by a given delta value",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "prefname", .desc = "Preference name" },
        .{ .tag = .Number, .name = "delta", .desc = "Delta value to increment/decrement (positive or negative)" },
    })[0..],
    .execute = execute,
};

fn execute(_: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;
    const delta = args[1].Number;

    const val = utilprefs.get(name).u;
    utilprefs.set_n(name, @intToFloat(f64, val) + delta);
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const p = @import("../util/utilprefs.zig");

pub const spec = types.MepoFnSpec{
    .name = "prefinc",
    .desc = "Increase or decrease a preference by the given delta value.",
    .args = &.{
        .{ .tag = .Text, .name = "pref", .desc = "Preference name" },
        .{ .tag = .Number, .name = "delta", .desc = "Delta value to increment/decrement (positive or negative)" },
    },
    .execute = execute,
};

fn execute(_: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;
    const delta = args[1].Number;

    if (p.lookup_pref_from_string(name)) |key| {
        const val = p.get(key).u;
        p.set_n(key, @as(f64, @floatFromInt(val)) + delta);
    }
}

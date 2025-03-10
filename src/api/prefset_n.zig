const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const p = @import("../util/utilprefs.zig");

pub const spec = types.MepoFnSpec{
    .name = "prefset_n",
    .desc = "Set a preference number value.",
    .args = &.{
        .{ .tag = .Text, .name = "pref", .desc = "Preference name" },
        .{ .tag = .Number, .name = "value", .desc = "Preference number value" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;
    const value = args[1].Number;

    if (std.mem.eql(u8, "tile_cache_network", name)) {
        mepo.tile_cache.set_network(value == 1);
    }
    if (p.lookup_pref_from_string(name)) |key| p.set_n(key, value);
}

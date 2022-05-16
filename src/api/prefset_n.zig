const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const utilprefs = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "prefset_n",
    .desc = "Set a preference number value",
    // TODO: document preference mapping table
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "prefname", .desc = "Preference name" },
        .{ .tag = .Number, .name = "prefvalue", .desc = "Preference number value" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;
    const value = args[1].Number;

    if (std.mem.eql(u8, "tile_cache_network", name)) {
        mepo.tile_cache.set_network(value == 1);
    } else {
        utilprefs.set_n(name, value);
    }
}

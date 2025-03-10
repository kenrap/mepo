const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const p = @import("../util/utilprefs.zig");

pub const spec = types.MepoFnSpec{
    .name = "preftoggle",
    .desc = "Toggle a boolean number preference between `1` and `0`.",
    .args = &.{
        .{ .tag = .Text, .name = "pref", .desc = "Preference name" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;

    if (std.mem.eql(u8, "tile_cache_network", name)) {
        const network_on = !(mepo.tile_cache.thread_download != null);
        mepo.tile_cache.set_network(network_on);
        if (p.lookup_pref_from_string(name)) |key| p.set_n(key, if (network_on) 1 else 0);
    } else {
        if (p.lookup_pref_from_string(name)) |key| p.toggle_bool(key);
    }
}

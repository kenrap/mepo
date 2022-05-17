const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const utilprefs = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "preftoggle",
    .desc = "Toggle a boolean number preference between `1` and `0`",
    // TODO: document prefrences table
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "prefname", .desc = "Preference name" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;

    if (std.mem.eql(u8, "tile_cache_network", name)) {
        const network_on = !(mepo.tile_cache.thread_download != null);
        mepo.tile_cache.set_network(network_on);
        utilprefs.set_n(name, if (network_on) 1 else 0);
    } else {
        utilprefs.toggle_bool(name);
    }
}

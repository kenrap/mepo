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

fn execute(_: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;

    utilprefs.toggle_bool(name);

    //if (std.mem.eql(u8, "tile_cache_network", name)) {
    //    mepo.tile_cache.set_network(!(mepo.tile_cache.thread_download != null));
    //}
}

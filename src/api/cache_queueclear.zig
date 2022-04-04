const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utildbg = @import("../util/utildbg.zig");
const config = @import("../config.zig");

pub const spec = .{
    .name = "cache_queueclear",
    .args = (&[_]types.MepoFnSpecArg{})[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    mepo.tile_cache.set_queue(null);
}

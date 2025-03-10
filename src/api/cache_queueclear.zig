const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utildbg = @import("../util/utildbg.zig");
const config = @import("../config.zig");

pub const spec = types.MepoFnSpec{
    .name = "cache_queueclear",
    .desc = "Clear any queued background downloading process queued with `cache_dlbbox` or `cache_dlradius`. Note this does not remove filesystem tiles, but simply stops in-progress downloading.",
    .args = &.{},
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    mepo.tile_cache.set_queue(null);
}

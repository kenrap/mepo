const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utildbg = @import("../util/utildbg.zig");
const config = @import("../config.zig");

pub fn f_cache_queueclear(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try cache_queueclear(mepo);
}

fn cache_queueclear(mepo: *Mepo) !void {
    mepo.tile_cache.set_queue_empty();
}

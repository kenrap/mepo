const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const utilarg = @import("../util/utilarg.zig");

pub const spec = .{
    .args = (&[_]types.MepoArgTag{ .Text, .Number })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;
    const delta = args[1].Number;

    for (&[_]struct { prop: []const u8, ptr: *u8 }{
        .{ .prop = "fontsize_ui", .ptr = &mepo.fontsize_ui },
        .{ .prop = "drag_scale", .ptr = &mepo.drag_scale },
        .{ .prop = "zoom", .ptr = &mepo.zoom },
        .{ .prop = "crosshair_size", .ptr = &mepo.crosshair_size },
        .{ .prop = "tile_cache_max_n_transfers", .ptr = &mepo.tile_cache.max_n_transfers },
    }) |stg| {
        if (std.mem.eql(u8, stg.prop, name)) {
            if (delta > 0) {
                stg.ptr.* +|= @floatToInt(u8, delta);
            } else {
                stg.ptr.* -|= @intCast(u8, try std.math.absInt(@floatToInt(i8, delta)));
            }
        }
    }
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .name = "prefinc",
    .desc = "Increase or decrease a preference by a given delta value",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "prefname", .desc = "Preference name" },
        .{ .tag = .Number, .name = "delta", .desc = "Delta value to increment/decrement (positive or negative)" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;
    const delta = args[1].Number;

    const val = mepo.prefs.get(name).u;
    mepo.prefs.set_n(name, @intToFloat(f64, val) + delta);

    //for (&[_]struct { prop: []const u8, ptr: *u8 }{
    //    .{ .prop = "fontsize_ui", .ptr = &mepo.fontsize_ui },
    //    .{ .prop = "drag_scale", .ptr = &mepo.drag_scale },
    //    .{ .prop = "zoom", .ptr = &mepo.zoom },
    //    .{ .prop = "crosshair_size", .ptr = &mepo.crosshair_size },
    //    .{ .prop = "tile_cache_max_n_transfers", .ptr = &mepo.tile_cache.max_n_transfers },
    //}) |stg| {
    //    if (std.mem.eql(u8, stg.prop, name)) {
    //        if (delta > 0) {
    //            stg.ptr.* +|= @floatToInt(u8, delta);
    //        } else {
    //            stg.ptr.* -|= @intCast(u8, try std.math.absInt(@floatToInt(i8, delta)));
    //        }
    //    }
    //}
}

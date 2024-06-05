const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const p = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "prefset_t",
    .desc = "Set a preference text value.",
    .args = &.{
        .{ .tag = .Text, .name = "prefname", .desc = "Preference name" },
        .{ .tag = .Text, .name = "prefvalue", .desc = "Preference number value" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;
    const value = args[1].Text;

    // Under the hood uses utilprefs.set_t
    // but unlike numerical updates, these generally need 'syncing' fns
    if (std.mem.eql(u8, "tile_cache_dir", name)) {
        try mepo.tile_cache.set_cache_dir(value);
    } else if (std.mem.eql(u8, "tile_cache_url", name)) {
        try mepo.tile_cache.set_cache_url(value);
    } else if (std.mem.startsWith(u8, name, "pingroup_") and std.mem.endsWith(u8, name, "_color")) {
        if (value.len < 1 or value[0] != '#') return error.InvalidColor;
        const color = try std.fmt.parseUnsigned(u24, value[1..], 16);
        if (p.lookup_pref_from_string(name)) |prefname| {
            p.set_n(prefname, @floatFromInt(color));
        }
    }
}

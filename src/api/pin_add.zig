const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_add(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const is_structural = args[0].Number == 1;
    const lat = args[1].Number;
    const lon = args[2].Number;
    const handle = args[3].Text;
    const name = args[4].Text;
    try pin_add(mepo, lat, lon, is_structural, handle, name);
}

fn pin_add(mepo: *Mepo, lat: f64, lon: f64, is_structural: bool, handle: [:0]const u8, name: [:0]const u8) !void {
    try mepo.pin_groups[mepo.pin_group_active].pins.append(.{
        .lat = lat,
        .lon = lon,
        .handle = if (handle.len == 0) null else try mepo.allocator.dupeZ(u8, handle),
        .category = if (is_structural) .Structural else .Instructive,
        .name = try mepo.allocator.dupeZ(u8, name),
        .metadata = std.array_hash_map.StringArrayHashMap([:0]const u8).init(mepo.allocator),
    });
}

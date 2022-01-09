const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_add(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const is_structural = args[0].Number == 1;
    const lat = args[1].Number;
    const lon = args[2].Number;
    const name = args[3].Text;
    try pin_add(mepo, lat, lon, is_structural, name);
}

fn pin_add(mepo: *Mepo, lat: f64, lon: f64, is_structural: bool, name: []const u8) !void {
    const name_heap_allocated = try mepo.allocator.dupe(u8, name);
    try mepo.pin_groups[mepo.pin_group_active].pins.append(.{
        .lat = lat,
        .lon = lon,
        .category = if (is_structural) .Structural else .Instructive,
        .name = name_heap_allocated,
        .metadata = std.array_hash_map.StringArrayHashMap([]const u8).init(mepo.allocator),
    });
}

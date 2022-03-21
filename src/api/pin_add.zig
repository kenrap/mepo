const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_add(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const group = @floatToInt(i32, args[0].Number);
    const is_structural = args[1].Number == 1;
    const lat = args[2].Number;
    const lon = args[3].Number;
    const handle = args[4].Text;
    const name = args[5].Text;
    try pin_add(mepo, group, is_structural, lat, lon, handle, name);
}

fn pin_add(mepo: *Mepo, group: i32, is_structural: bool, lat: f64, lon: f64, handle: [:0]const u8, name: [:0]const u8) !void {
    const pin_group = if (group < 0) mepo.pin_group_active else @intCast(usize, group);
    if (name.len == 0) return;

    try mepo.pin_groups[pin_group].pins.append(.{
        .lat = lat,
        .lon = lon,
        .handle = if (handle.len == 0) null else try mepo.allocator.dupeZ(u8, handle),
        .category = if (is_structural) .Structural else .Instructive,
        .name = try mepo.allocator.dupeZ(u8, name),
        .metadata = std.array_hash_map.StringArrayHashMap([:0]const u8).init(mepo.allocator),
    });
}

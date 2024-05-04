const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_add",
    .desc = "Add a pin to the map.",
    .args = &.{
        .{ .tag = .Number, .name = "group_number", .desc = "Group number" },
        .{ .tag = .Number, .name = "is_structural", .desc = "If set to `1`, will be a 'structural' pin which is useful for curved paths and similar" },
        .{ .tag = .Number, .name = "lat", .desc = "Latitude" },
        .{ .tag = .Number, .name = "lon", .desc = "Longitude" },
        .{ .tag = .Text, .name = "handle", .desc = "*Unique* handle to refer to pin; can use this handle subsequently with `pin_meta` to update pin metadata" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try pin_add(mepo, @intFromFloat(args[0].Number), args[1].Number == 1, args[2].Number, args[3].Number, args[4].Text);
}

fn pin_add(mepo: *Mepo, group: i32, is_structural: bool, lat: f64, lon: f64, handle: [:0]const u8) !void {
    const pin_group: usize = if (group < 0) mepo.pin_group_active else @intCast(group);
    defer mepo.blit_pinlayer_cache.clearAndFree();

    // E.g. nop if adding a pin_handle that already exists
    if (handle.len != 0) {
        for (mepo.pin_groups[pin_group].items) |pin| {
            if (pin.handle) |pin_handle| {
                if (std.mem.eql(u8, pin_handle, handle)) return;
            }
        }
    }

    try mepo.pin_groups[pin_group].append(.{
        .lat = lat,
        .lon = lon,
        .handle = if (handle.len == 0) null else try mepo.allocator.dupeZ(u8, handle), // E.g. for routes.. pins dont have handles
        .category = if (is_structural) .Structural else .Instructive,
        .metadata = std.array_hash_map.StringArrayHashMap([:0]const u8).init(mepo.allocator),
    });
}

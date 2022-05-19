const std = @import("std");

const PrefValueEnum = enum { b, t, f, u };
const PrefValueUnion = union(PrefValueEnum) { b: bool, t: ?[:0]const u8, f: f64, u: u8 };
const PrefMapping = struct {
    name: []const u8,
    value: PrefValueUnion,
    desc: []const u8,
};

const n_prefs = 18;
pub var prefs_mapping: [n_prefs]PrefMapping = mapping: {
    var mapping: [n_prefs]PrefMapping = undefined;
    mapping[0] = .{ .name = "lat", .value = .{ .f = 40.78392 }, .desc = "TODO" };
    mapping[1] = .{ .name = "lon", .value = .{ .f = -73.96442 }, .desc = "TODO" };
    mapping[2] = .{ .name = "zoom", .value = .{ .u = 14 }, .desc = "TODO" };
    mapping[3] = .{ .name = "debug_message_enabled", .value = .{ .b = true }, .desc = "TODO" };
    mapping[4] = .{ .name = "distance_unit_tf_km_mi", .value = .{ .b = false }, .desc = "TODO" };
    mapping[5] = .{ .name = "overlay_debugbar", .value = .{ .b = true }, .desc = "TODO" };
    mapping[6] = .{ .name = "help", .value = .{ .b = false }, .desc = "TODO" };
    mapping[7] = .{ .name = "overlay_pindetails", .value = .{ .b = true }, .desc = "TODO" };
    mapping[8] = .{ .name = "crosshair_size", .value = .{ .u = 15 }, .desc = "TODO" };
    mapping[9] = .{ .name = "drag_scale", .value = .{ .u = 2 }, .desc = "TODO" };
    mapping[10] = .{ .name = "fontsize_ui", .value = .{ .u = 20 }, .desc = "TODO" };
    mapping[11] = .{ .name = "debug_tiles", .value = .{ .b = false }, .desc = "TODO" };
    mapping[12] = .{ .name = "debug_stderr", .value = .{ .b = false }, .desc = "TODO" };
    mapping[13] = .{ .name = "tile_cache_max_n_transfers", .value = .{ .u = 20 }, .desc = "TODO" };
    mapping[14] = .{ .name = "tile_cache_expiry_seconds", .value = .{ .f = -1 }, .desc = "TODO" };
    mapping[15] = .{ .name = "tile_cache_network", .value = .{ .b = true }, .desc = "TODO" };
    mapping[16] = .{ .name = "tile_cache_dir", .value = .{ .t = null }, .desc = "TODO" };
    mapping[17] = .{ .name = "tile_cache_url", .value = .{ .t = null }, .desc = "TODO" };
    break :mapping mapping;
};

pub fn get_u8(prefname: []const u8) f64 {
    for (prefs_mapping) |pref| {
        if (std.mem.eql(u8, pref.name, prefname)) return pref.value.u;
    }
    return 0;
}

pub fn get(prefname: []const u8) PrefValueUnion {
    for (prefs_mapping) |pref| {
        if (std.mem.eql(u8, pref.name, prefname)) {
            return pref.value;
        }
    }
    return .{ .b = false };
}

pub fn set_n(prefname: []const u8, value: f64) void {
    for (prefs_mapping) |*pref| {
        if (std.mem.eql(u8, pref.name, prefname)) {
            switch (pref.value) {
                .b => {
                    pref.value = .{ .b = value == 1 };
                },
                .u => {
                    pref.value = .{ .u = @floatToInt(u8, value) };
                },
                .f => {
                    pref.value = .{ .f = value };
                },
                .t => {},
            }
        }
    }
}

pub fn set_t(allocator: std.mem.Allocator, prefname: []const u8, value: []const u8) !void {
    for (prefs_mapping) |*pref| {
        if (std.mem.eql(u8, pref.name, prefname)) {
            switch (pref.value) {
                .t => {
                    if (pref.value.t) |heap_allocated_text| allocator.free(heap_allocated_text);
                    pref.value.t = try allocator.dupeZ(u8, value);
                },
                else => {}
            }
        }
    }
}

pub fn toggle_bool(prefname: []const u8) void {
    for (prefs_mapping) |*pref| {
        if (std.mem.eql(u8, pref.name, prefname)) {
            switch (pref.value) {
                .b => {
                    pref.value = .{ .b = !pref.value.b };
                },
                else => {},
            }
        }
    }
}

const std = @import("std");

const PrefValueEnum = enum { b, t, f, u };
const PrefValueUnion = union(PrefValueEnum) { b: bool, t: ?[:0]const u8, f: f64, u: u8 };

pub const pref = enum(u8) {
    lat,
    lon,
    zoom,
    debug_message_enabled,
    distance_unit_tf_km_mi,
    overlay_debugbar,
    help,
    overlay_pindetails,
    crosshair_size,
    drag_scale,
    fontsize_ui,
    debug_tiles,
    debug_stderr,
    tile_cache_max_n_transfers,
    tile_cache_expiry_seconds,
    tile_cache_network,
    tile_cache_dir,
    tile_cache_url,
};

const PrefMapping = struct {
    name: []const u8,
    value: PrefValueUnion,
    desc: []const u8,
};

const n_prefs = 18;
pub var prefs_mapping: [n_prefs]PrefMapping = mapping: {
    var mapping: [n_prefs]PrefMapping = undefined;
    mapping[@enumToInt(pref.lat)] = .{ .name = "lat", .value = .{ .f = 40.78392 }, .desc = "TODO" };
    mapping[@enumToInt(pref.lon)] = .{ .name = "lon", .value = .{ .f = -73.96442 }, .desc = "TODO" };
    mapping[@enumToInt(pref.zoom)] = .{ .name = "zoom", .value = .{ .u = 14 }, .desc = "TODO" };
    mapping[@enumToInt(pref.debug_message_enabled)] = .{ .name = "debug_message_enabled", .value = .{ .b = true }, .desc = "TODO" };
    mapping[@enumToInt(pref.distance_unit_tf_km_mi)] = .{ .name = "distance_unit_tf_km_mi", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.overlay_debugbar)] = .{ .name = "overlay_debugbar", .value = .{ .b = true }, .desc = "TODO" };
    mapping[@enumToInt(pref.help)] = .{ .name = "help", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.overlay_pindetails)] = .{ .name = "overlay_pindetails", .value = .{ .b = true }, .desc = "TODO" };
    mapping[@enumToInt(pref.crosshair_size)] = .{ .name = "crosshair_size", .value = .{ .u = 15 }, .desc = "TODO" };
    mapping[@enumToInt(pref.drag_scale)] = .{ .name = "drag_scale", .value = .{ .u = 2 }, .desc = "TODO" };
    mapping[@enumToInt(pref.fontsize_ui)] = .{ .name = "fontsize_ui", .value = .{ .u = 20 }, .desc = "TODO" };
    mapping[@enumToInt(pref.debug_tiles)] = .{ .name = "debug_tiles", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.debug_stderr)] = .{ .name = "debug_stderr", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.tile_cache_max_n_transfers)] = .{ .name = "tile_cache_max_n_transfers", .value = .{ .u = 20 }, .desc = "TODO" };
    mapping[@enumToInt(pref.tile_cache_expiry_seconds)] = .{ .name = "tile_cache_expiry_seconds", .value = .{ .f = -1 }, .desc = "TODO" };
    mapping[@enumToInt(pref.tile_cache_network)] = .{ .name = "tile_cache_network", .value = .{ .b = true }, .desc = "TODO" };
    mapping[@enumToInt(pref.tile_cache_dir)] = .{ .name = "tile_cache_dir", .value = .{ .t = null }, .desc = "TODO" };
    mapping[@enumToInt(pref.tile_cache_url)] = .{ .name = "tile_cache_url", .value = .{ .t = null }, .desc = "TODO" };
    break :mapping mapping;
};

pub fn get(prefname: pref) PrefValueUnion {
    return prefs_mapping[@enumToInt(prefname)].value;
}

pub fn set_n(prefname: pref, value: f64) void {
    switch (prefs_mapping[@enumToInt(prefname)].value) {
        .b => {
            prefs_mapping[@enumToInt(prefname)].value = .{ .b = value == 1 };
        },
        .u => {
            prefs_mapping[@enumToInt(prefname)].value = .{ .u = @floatToInt(u8, value) };
        },
        .f => {
            prefs_mapping[@enumToInt(prefname)].value = .{ .f = value };
        },
        .t => {},
    }
}

pub fn set_t(allocator: std.mem.Allocator, prefname: pref, value: []const u8) !void {
    if (prefs_mapping[@enumToInt(prefname)].value.t) |heap_allocated_text| allocator.free(heap_allocated_text);
    prefs_mapping[@enumToInt(prefname)].value.t = try allocator.dupeZ(u8, value);
}

pub fn lookup_pref_from_string(prefname: []const u8) ?pref {
    for (prefs_mapping) |p, i| {
        if (std.mem.eql(u8, p.name, prefname)) return @intToEnum(pref, i);
    }
    return null;
}

pub fn toggle_bool(prefname: pref) void {
    switch (prefs_mapping[@enumToInt(prefname)].value) {
        .b => {
            prefs_mapping[@enumToInt(prefname)].value = .{ .b = !prefs_mapping[@enumToInt(prefname)].value.b };
        },
        else => {},
    }
}

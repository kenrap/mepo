const std = @import("std");

const PrefValueEnum = enum { b, t, f, u, u24 };
const PrefValueUnion = union(PrefValueEnum) { b: bool, t: ?[:0]const u8, f: f64, u: u8, u24: u24 };

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
    debug_stderr,
    tile_cache_max_n_transfers,
    tile_cache_expiry_seconds,
    tile_cache_network,
    tile_cache_dir,
    tile_cache_url,
    pingroup_0_ordered,
    pingroup_1_ordered,
    pingroup_2_ordered,
    pingroup_3_ordered,
    pingroup_4_ordered,
    pingroup_5_ordered,
    pingroup_6_ordered,
    pingroup_7_ordered,
    pingroup_8_ordered,
    pingroup_9_ordered,
    pingroup_0_color,
    pingroup_1_color,
    pingroup_2_color,
    pingroup_3_color,
    pingroup_4_color,
    pingroup_5_color,
    pingroup_6_color,
    pingroup_7_color,
    pingroup_8_color,
    pingroup_9_color,
};

const PrefMapping = struct {
    name: []const u8,
    value: PrefValueUnion,
    bounds: ?struct {
        min: f64,
        max: f64,
    } = null,
    desc: []const u8,
};

const n_prefs = 38;
pub var prefs_mapping: [n_prefs]PrefMapping = mapping: {
    var mapping: [n_prefs]PrefMapping = undefined;
    mapping[@enumToInt(pref.lat)] = .{ .name = "lat", .value = .{ .f = 40.78392 }, .bounds = .{ .min = -90, .max = 90 }, .desc = "Latitude of the map" };
    mapping[@enumToInt(pref.lon)] = .{ .name = "lon", .value = .{ .f = -73.96442 }, .bounds = .{ .min = -180, .max = 180 }, .desc = "Longitude of the map" };
    mapping[@enumToInt(pref.zoom)] = .{ .name = "zoom", .value = .{ .u = 14, }, .bounds = .{ .min = 0, .max = 19 }, .desc = "Zoom level of the map (should be set between 0-19)" };
    mapping[@enumToInt(pref.debug_message_enabled)] = .{ .name = "debug_message_enabled", .value = .{ .b = true }, .desc = "Whether debug overlay message should be shown in the UI" };
    mapping[@enumToInt(pref.distance_unit_tf_km_mi)] = .{ .name = "distance_unit_tf_km_mi", .value = .{ .b = false }, .desc = "Whether to show distance in km or mi" };
    mapping[@enumToInt(pref.overlay_debugbar)] = .{ .name = "overlay_debugbar", .value = .{ .b = true }, .desc = "Whether to show the debug bar" };
    mapping[@enumToInt(pref.help)] = .{ .name = "help", .value = .{ .b = false }, .desc = "Whether to show the help overlay" };
    mapping[@enumToInt(pref.overlay_pindetails)] = .{ .name = "overlay_pindetails", .value = .{ .b = true }, .desc = "Whether to show the pin detail overlay" };
    mapping[@enumToInt(pref.crosshair_size)] = .{ .name = "crosshair_size", .value = .{ .u = 15 }, .bounds = .{ .min = 0, .max = 300 }, .desc = "Pixel size of the crosshairs" };
    mapping[@enumToInt(pref.drag_scale)] = .{ .name = "drag_scale", .value = .{ .u = 2 }, .bounds = .{ .min = 1, .max = 200 }, .desc = "Scale for dragging" };
    mapping[@enumToInt(pref.fontsize_ui)] = .{ .name = "fontsize_ui", .value = .{ .u = 20 }, .bounds = .{ .min = 1, .max = 200 }, .desc = "Size of the font in the UI" };
    mapping[@enumToInt(pref.debug_stderr)] = .{ .name = "debug_stderr", .value = .{ .b = false }, .desc = "Send debug information to STDERR" };
    mapping[@enumToInt(pref.tile_cache_max_n_transfers)] = .{ .name = "tile_cache_max_n_transfers", .value = .{ .u = 20 }, .bounds = .{ .min = 1, .max = 9999 }, .desc = "Maximum number of concurrent transfers for curl" };
    mapping[@enumToInt(pref.tile_cache_expiry_seconds)] = .{ .name = "tile_cache_expiry_seconds", .value = .{ .f = -1 }, .bounds = .{ .min = -1, .max = 99999999 }, .desc = "Number of seconds before a downloaded tiledata should be considered invalid" };
    mapping[@enumToInt(pref.tile_cache_network)] = .{ .name = "tile_cache_network", .value = .{ .b = true }, .desc = "Whether to donwload new tiledata from external servers; if 0 that means you're offline" };
    mapping[@enumToInt(pref.tile_cache_dir)] = .{ .name = "tile_cache_dir", .value = .{ .t = null }, .desc = "Path of directory to store the downloaded tiles" };
    mapping[@enumToInt(pref.tile_cache_url)] = .{ .name = "tile_cache_url", .value = .{ .t = null }, .desc = "URL source for the tiles, uses %1/%2/%3 to represent X/Y/Z" };

    mapping[@enumToInt(pref.pingroup_0_ordered)] = .{ .name = "pingroup_0_ordered", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_1_ordered)] = .{ .name = "pingroup_1_ordered", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_2_ordered)] = .{ .name = "pingroup_2_ordered", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_3_ordered)] = .{ .name = "pingroup_3_ordered", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_4_ordered)] = .{ .name = "pingroup_4_ordered", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_5_ordered)] = .{ .name = "pingroup_5_ordered", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_6_ordered)] = .{ .name = "pingroup_6_ordered", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_7_ordered)] = .{ .name = "pingroup_7_ordered", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_8_ordered)] = .{ .name = "pingroup_8_ordered", .value = .{ .b = false }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_9_ordered)] = .{ .name = "pingroup_9_ordered", .value = .{ .b = false }, .desc = "TODO" };

    mapping[@enumToInt(pref.pingroup_0_color)] = .{ .name = "pingroup_0_color", .value = .{ .u24 = 0x0 }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_1_color)] = .{ .name = "pingroup_1_color", .value = .{ .u24 = 0x0 }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_2_color)] = .{ .name = "pingroup_2_color", .value = .{ .u24 = 0x0 }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_3_color)] = .{ .name = "pingroup_3_color", .value = .{ .u24 = 0x0 }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_4_color)] = .{ .name = "pingroup_4_color", .value = .{ .u24 = 0x0 }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_5_color)] = .{ .name = "pingroup_5_color", .value = .{ .u24 = 0x0 }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_6_color)] = .{ .name = "pingroup_6_color", .value = .{ .u24 = 0x0 }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_7_color)] = .{ .name = "pingroup_7_color", .value = .{ .u24 = 0x0 }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_8_color)] = .{ .name = "pingroup_8_color", .value = .{ .u24 = 0x0 }, .desc = "TODO" };
    mapping[@enumToInt(pref.pingroup_9_color)] = .{ .name = "pingroup_9_color", .value = .{ .u24 = 0x0 }, .desc = "TODO" };

    break :mapping mapping;
};

pub fn get(prefname: pref) PrefValueUnion {
    return prefs_mapping[@enumToInt(prefname)].value;
}

pub fn set_n(prefname: pref, value: f64) void {
    var bounded_value : f64 = value;
    if (prefs_mapping[@enumToInt(prefname)].bounds) |bounds| {
        if (bounded_value > bounds.max) bounded_value = bounds.max;
        if (bounded_value < bounds.min) bounded_value = bounds.min;
    }

    switch (prefs_mapping[@enumToInt(prefname)].value) {
        .b => {
            prefs_mapping[@enumToInt(prefname)].value = .{ .b = value == 1 };
        },
        .u => {
            if (bounded_value > std.math.maxInt(u8)) bounded_value = std.math.maxInt(u8);
            if (bounded_value < std.math.minInt(u8)) bounded_value = std.math.minInt(u8);
            prefs_mapping[@enumToInt(prefname)].value = .{ .u = @floatToInt(u8, bounded_value) };
        },
        .f => {
            prefs_mapping[@enumToInt(prefname)].value = .{ .f = value };
        },
        .t => {},
        .u24 => {
            if (bounded_value > std.math.maxInt(u24)) bounded_value = std.math.maxInt(u24);
            if (bounded_value < std.math.minInt(u24)) bounded_value = std.math.minInt(u24);
            prefs_mapping[@enumToInt(prefname)].value = .{ .u24 = @floatToInt(u24, value) };
        },
    }
}

pub fn pingroup_prop(pingroup: usize, prop: enum { Ordered, Color }) pref {
    if (pingroup == 0 and prop == .Ordered) return pref.pingroup_0_ordered;
    if (pingroup == 1 and prop == .Ordered) return pref.pingroup_1_ordered;
    if (pingroup == 2 and prop == .Ordered) return pref.pingroup_2_ordered;
    if (pingroup == 3 and prop == .Ordered) return pref.pingroup_3_ordered;
    if (pingroup == 4 and prop == .Ordered) return pref.pingroup_4_ordered;
    if (pingroup == 5 and prop == .Ordered) return pref.pingroup_5_ordered;
    if (pingroup == 6 and prop == .Ordered) return pref.pingroup_6_ordered;
    if (pingroup == 7 and prop == .Ordered) return pref.pingroup_7_ordered;
    if (pingroup == 8 and prop == .Ordered) return pref.pingroup_8_ordered;
    if (pingroup == 9 and prop == .Ordered) return pref.pingroup_9_ordered;
    if (pingroup == 0 and prop == .Color) return pref.pingroup_0_color;
    if (pingroup == 1 and prop == .Color) return pref.pingroup_1_color;
    if (pingroup == 2 and prop == .Color) return pref.pingroup_2_color;
    if (pingroup == 3 and prop == .Color) return pref.pingroup_3_color;
    if (pingroup == 4 and prop == .Color) return pref.pingroup_4_color;
    if (pingroup == 5 and prop == .Color) return pref.pingroup_5_color;
    if (pingroup == 6 and prop == .Color) return pref.pingroup_6_color;
    if (pingroup == 7 and prop == .Color) return pref.pingroup_7_color;
    if (pingroup == 8 and prop == .Color) return pref.pingroup_8_color;
    if (pingroup == 9 and prop == .Color) return pref.pingroup_9_color;
    return pref.lat;
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

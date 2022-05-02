const std = @import("std");

const PrefMapping = struct {
    name: []const u8,
    value: union{
        b: bool,
        t: []const u8,
        n: f64,
        u : u8
    },
};

prefs_mapping : *const [9]PrefMapping = &[_]PrefMapping{
        .{ .name = "debug_message_enabled", .value = .{ .b = true } },
        .{ .name = "distance_unit_tf_km_mi", .value = .{ .b = false } },
        .{ .name = "overlay_debugbar", .value = .{ .b = true } },
        .{ .name = "help", .value = .{ .b = false } },
        .{ .name = "overlay_pindetails", .value = .{ .b = true } },
        .{ .name = "crosshair_size", .value = .{ .u = 15 } },
        .{ .name = "drag_scale", .value = .{ .u = 2 } },
        .{ .name = "fontsize_ui", .value = .{ .u = 20 } },
        .{ .name = "zoom", .value = .{ .u = 14 } },
},

pub fn get_u8(prefs: *@This(), prefname: []const u8) f64 {
    for (prefs.prefs_mapping) |pref| {
        if (std.mem.eql(u8, pref.name, prefname)) return pref.value.u;
    }
    return 0;
}

pub fn get_b(prefs: *@This(), prefname: []const u8) bool {
    for (prefs.prefs_mapping) |pref| {
        if (std.mem.eql(u8, pref.name, prefname)) return pref.value.b;
    }
    return false;
}

pub fn init() @This() {
    return @as(@This(), .{});
}

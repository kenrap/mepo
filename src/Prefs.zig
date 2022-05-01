const std = @import("std");

const PrefMapping = struct {
    name: []const u8,
    value: union{
        b: bool,
        t: []const u8,
        n: f64,
        u : u8
    },
    value_type: type,
};

prefs : []PrefMapping = (&[_]PrefMapping{
    .{ .name = "debug_message_enabled", .value_type = bool, .value = .{ .b = true } },
    .{ .name = "distance_unit_tf_km_mi", .value_type = bool, .value = .{ .b = false } },
    .{ .name = "overlay_debugbar", .value_type = bool, .value = .{ .b = true } },
    .{ .name = "help", .value_type = bool, .value = .{ .b = false } },
    .{ .name = "overlay_pindetails", .value_type = bool, .value = .{ .b = true } },
    .{ .name = "crosshair_size", .value_type = u8, .value = .{ .u = 15 } },
    .{ .name = "drag_scale", .value_type = u8, .value = .{ .u = 2 } },
    .{ .name = "fontsize_ui", .value_type = u8, .value = .{ .u = 20 } },
    .{ .name = "zoom", .value_type = u8, .value = .{ .u = 14 } },
})[0..],

pub fn get_u8(prefs: *@This(), prefname: []const u8) f64 {
    for (prefs) |pref| {
        if (std.mem.eql(u8, pref.name, prefname)) return pref.value.u;
    }
}

//pub fn get_b(prefs: *@This(), prefname: []const u8) bool {
//}

pub fn init() @This() {
    return @as(@This(), .{});
}

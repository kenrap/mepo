const std = @import("std");

const PrefValueEnum = enum { b, t, n, u };
const PrefValueUnion = union(PrefValueEnum) { b: bool, t: []const u8, n: f64, u: u8 };
const PrefMapping = struct {
    name: []const u8,
    value: PrefValueUnion,
};

prefs_mapping: [10]PrefMapping = undefined,

pub fn get_u8(prefs: *@This(), prefname: []const u8) f64 {
    for (prefs.prefs_mapping) |pref| {
        if (std.mem.eql(u8, pref.name, prefname)) return pref.value.u;
    }
    return 0;
}

pub fn get(prefs: *@This(), prefname: []const u8) PrefValueUnion {
    for (prefs.prefs_mapping) |pref| {
        if (std.mem.eql(u8, pref.name, prefname)) {
            return pref.value;
        }
    }
    return .{ .b = false };
}

pub fn set_n(prefs: *@This(), prefname: []const u8, value: f64) void {
    for (prefs.prefs_mapping) |*pref| {
        if (std.mem.eql(u8, pref.name, prefname)) {
            switch (pref.value) {
                .b => {
                    pref.value = .{ .b = value == 1 };
                },
                .u => {
                    pref.value = .{ .u = @floatToInt(u8, value) };
                },
                .n => {
                    pref.value = .{ .n = value };
                },
                .t => {},
            }
        }
    }
}

pub fn toggle_bool(prefs: *@This(), prefname: []const u8) void {
    for (prefs.prefs_mapping) |*pref| {
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

pub fn init() @This() {
    return @as(@This(), .{
        .prefs_mapping = mapping: {
            var prefs_mapping: [10]PrefMapping = undefined;
            prefs_mapping[0] = .{ .name = "debug_message_enabled", .value = .{ .b = true } };
            prefs_mapping[1] = .{ .name = "distance_unit_tf_km_mi", .value = .{ .b = false } };
            prefs_mapping[2] = .{ .name = "overlay_debugbar", .value = .{ .b = true } };
            prefs_mapping[3] = .{ .name = "help", .value = .{ .b = false } };
            prefs_mapping[4] = .{ .name = "overlay_pindetails", .value = .{ .b = true } };
            prefs_mapping[5] = .{ .name = "crosshair_size", .value = .{ .u = 15 } };
            prefs_mapping[6] = .{ .name = "drag_scale", .value = .{ .u = 2 } };
            prefs_mapping[7] = .{ .name = "fontsize_ui", .value = .{ .u = 20 } };
            prefs_mapping[8] = .{ .name = "zoom", .value = .{ .u = 14 } };
            prefs_mapping[9] = .{ .name = "debug_tiles", .value = .{ .b = false } };
            break :mapping prefs_mapping;
        },
    });
}

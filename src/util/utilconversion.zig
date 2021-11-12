const std = @import("std");
const config = @import("../config.zig");
const cmath = @cImport({
    @cInclude("math.h");
});

pub fn lon_to_px_x(lon: f64, zoom: u32) i32 {
    const tilex: f64 = (lon + 180.0) / 360.0;
    return @floatToInt(i32, tilex * zoom_bit(zoom));
}

pub fn lat_to_px_y(lat: f64, zoom: u32) i32 {
    // Currently there's a bug in zig std.math.asinh where negative
    // values are not respected. TODO: switch back / remove cmath reference
    // once when zig MR is merged in 0.8.2 or 0.9
    //
    // https://github.com/ziglang/zig/pull/9940
    const tiley = (1.0 - cmath.asinh(std.math.tan(lat * std.math.pi / 180.0)) / std.math.pi) / 2.0;
    return @floatToInt(i32, tiley * zoom_bit(zoom));
}

pub fn px_x_to_lon(px: i32, zoom: u32) f64 {
    return @intToFloat(f64, px) / zoom_bit(zoom) * 360.0 - 180.0;
}

pub fn px_y_to_lat(px: i32, zoom: u32) f64 {
    const n = std.math.pi - 2.0 * std.math.pi * @intToFloat(f64, px) / zoom_bit(zoom);
    return 180.0 / std.math.pi * std.math.atan(0.5 * (std.math.exp(n) - std.math.exp(-n)));
}

pub fn distance_km_haversine(lat_a: f64, lon_a: f64, lat_b: f64, lon_b: f64) f64 {
    const phi_a = (90.0 - lat_a) * std.math.pi / 180.0;
    const phi_b = (90.0 - lat_b) * std.math.pi / 180.0;
    const theta_a = lon_a * std.math.pi / 180.0;
    const theta_b = lon_b * std.math.pi / 180.0;

    const c = (std.math.sin(phi_a) *
        std.math.sin(phi_b) *
        std.math.cos(theta_a - theta_b) +
        std.math.cos(phi_a) *
        std.math.cos(phi_b));
    const arc = std.math.acos(c);
    const km_radius = 6371.0;

    const distance = arc * km_radius;

    return if (std.math.isNan(distance)) 0 else distance;
}

fn zoom_bit(zoom: u32) f32 {
    return @intToFloat(f32, (@intCast(i32, config.Tsize) << @intCast(u5, zoom)));
}

test "lon_to_px_x roundtrips with px_x_to_lon" {
    const lon: f64 = 22.0;
    const zoom = 3;
    const conv_x = lon_to_px_x(lon, zoom);
    const conv_lon = px_x_to_lon(conv_x, zoom);
    try std.testing.expect(std.math.approxEqAbs(f64, lon, conv_lon, 0.2));
}

test "lat_to_px_y roundtrips with px_y_to_lat" {
    const lat: f64 = 22.0;
    const zoom = 3;
    const conv_y = lat_to_px_y(lat, zoom);
    const conv_lat = px_y_to_lat(conv_y, zoom);
    try std.testing.expect(std.math.approxEqAbs(f64, lat, conv_lat, 0.2));
}

test "distance_km_haversine" {
    const lat_a: f64 = 22.0;
    const lon_a: f64 = 10.0;
    const lat_b: f64 = 24.0;
    const lon_b: f64 = 32.0;
    const expect_result = 2260.47;
    const result = distance_km_haversine(lat_a, lon_a, lat_b, lon_b);
    try std.testing.expect(std.math.approxEqAbs(f64, result, expect_result, 0.2));
}

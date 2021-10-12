const std = @import("std");
const config = @import("../config.zig");

pub fn lon_to_px_x(lon: f64, zoom: u32) i32 {
    const tilex: f64 = (lon + 180.0) / 360.0;
    return @floatToInt(i32, tilex * zoom_bit(zoom));
}

pub fn lat_to_px_y(lat: f64, zoom: u32) i32 {
    const tiley = (1.0 - std.math.asinh(std.math.tan(lat * std.math.pi / 180.0)) / std.math.pi) / 2.0;
    return @floatToInt(i32, tiley * zoom_bit(zoom));
}

pub fn px_x_to_lon(px: i32, zoom: u32) f64 {
    return @intToFloat(f64, px) / zoom_bit(zoom) * 360.0 - 180.0;
}

pub fn px_y_to_lat(px: i32, zoom: u32) f64 {
    const n = std.math.pi - 2.0 * std.math.pi * @intToFloat(f64, px) / zoom_bit(zoom);
    return 180.0 / std.math.pi * std.math.atan(0.5 * (std.math.exp(n) - std.math.exp(-n)));
}

fn zoom_bit(zoom: u32) f32 {
    return @intToFloat(f32, (@intCast(i32, config.Tsize) << @intCast(u5, zoom)));
}

test "lon_to_px_x roundtrips with px_x_to_lon" {
    const lon: f64 = 22.0;
    const zoom = 3;
    const conv_x = lon_to_px_x(lon, zoom);
    const conv_lon = px_x_to_lon(conv_x, zoom);
    try std.testing.expectEqual(round_to(lon, 1), round_to(conv_lon, 1));
}

test "lat_to_px_y roundtrips with px_y_to_lat" {
    const lat: f64 = 22.0;
    const zoom = 3;
    const conv_y = lat_to_px_y(lat, zoom);
    const conv_lat = px_y_to_lat(conv_y, zoom);
    try std.testing.expectEqual(round_to(lat, 1), round_to(conv_lat, 1));
}

fn round_to(input: f64, n_decimals: u32) f64 {
    return std.math.round(input * @intToFloat(f64, std.math.pow(u32, 10, n_decimals)));
}

const std = @import("std");

pub fn lon_to_px(lon: f64, zoom: u32)  i32 { 
    var tilex : f64 = (lon + 180.0) / 360.0;
    return @floatToInt(i32, tilex * zoom_bit(zoom));
}

pub fn lat_to_px(lat: f64, zoom: u32) i32 { 
    var tiley = (1.0 - std.math.asinh(std.math.tan(lat * std.math.pi / 180.0)) / std.math.pi) / 2.0;
    return @floatToInt(i32, tiley * zoom_bit(zoom));
}

pub fn px_to_lon(px: i32, zoom: u32) f64 {
    return @intToFloat(f64, px) / zoom_bit(zoom) * 360.0 - 180.0;
}

pub fn px_to_lat(px: i32, zoom: u32) f64 {
    var n = std.math.pi - 2.0 * std.math.pi * @intToFloat(f64, px) / zoom_bit(zoom);
    return 180.0 / std.math.pi * std.math.atan(0.5 * (std.math.exp(n) - std.math.exp(-n)));
}

fn zoom_bit(zoom: u32) f32 {
    return @intToFloat(f32, (@intCast(i32, 256) << @intCast(u5, zoom)));
}

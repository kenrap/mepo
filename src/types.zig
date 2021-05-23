const std = @import("std");
const Fmap = @import("Fmap.zig");

pub const Latlon = struct { lat: f64, lon: f64 };
pub const TileSpec = struct { x: u32, y: u32, z: u8 };

pub const Pin = struct {
  lat: f64,
  lon: f64,
  name: []const u8
};

pub const MepoArgTag = enum { Text, Number };
pub const MepoArg = union(MepoArgTag) {
    Text: [:0]const u8,
    Number: f64
};
pub const MepoFn = fn (fmap: *Fmap, args: [5]MepoArg) anyerror!void;
pub const MepoFnTable = std.array_hash_map.StringArrayHashMap(MepoFn);

const std = @import("std");
const Mepo = @import("Mepo.zig");

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

pub const MepoFnNargs = 6;
pub const MepoFn = fn (mepo: *Mepo, args: [MepoFnNargs]MepoArg) anyerror!void;
pub const MepoFnTable = std.array_hash_map.StringArrayHashMap(MepoFn);

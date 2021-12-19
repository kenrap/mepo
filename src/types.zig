const std = @import("std");
const Mepo = @import("Mepo.zig");
const sdl = @import("./sdlshim.zig");

pub const Latlon = struct { lat: f64, lon: f64 };
pub const XYZ = struct { x: u32, y: u32, z: u8 };

pub const Pin = struct {
    lat: f64,
    lon: f64,
    name: []const u8,
    category: enum { Instructive, Structural } = .Instructive,
};
pub const PinGroup = struct {
    pins: std.ArrayList(Pin),
    ordered: bool = false,
    color: u24 = 0x000000,
};

pub const MepoArgTag = enum { Text, Number };
pub const MepoArg = union(MepoArgTag) { Text: [:0]const u8, Number: f64 };

pub const MepoFnNargs = 6;
pub const MepoFn = fn (mepo: *Mepo, args: [MepoFnNargs]MepoArg) anyerror!void;
pub const MepoFnTable = std.array_hash_map.StringArrayHashMap(MepoFn);

pub const KeyInput = struct { keycode: sdl.SDL_KeyCode, keymod: sdl.SDL_Keymod };

pub const Pending = enum { None, Redraw, Drag };

pub const Color = struct {
    value: u24 = 0x000000,
    opacity: u8 = 255,

    pub fn sdl(self: @This()) sdl.SDL_Color {
        return .{
            .r = @intCast(u8, self.value >> 16),
            .g = @intCast(u8, self.value >> 8 & 0xff),
            .b = @intCast(u8, self.value & 0xff),
            .a = self.opacity,
        };
    }
};

pub const LatLonBox = struct {
    topleft_lat: f64,
    topleft_lon: f64,
    bottomright_lat: f64,
    bottomright_lon: f64,
};

pub const BoxAlignment = struct {
    w: ?usize = null,
    h: ?usize = null,
    align_x: enum { Left, Center, Right } = .Left,
    align_y: enum { Top, Center, Bottom } = .Top,
};

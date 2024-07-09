const std = @import("std");
const Mepo = @import("Mepo.zig");
const sdl = @import("./sdlshim.zig");

pub const Latlon = struct { lat: f64, lon: f64 };
pub const XYZ = struct { x: u32, y: u32, z: u8 };
pub const XYZAndOffsets = struct {
    xyz: XYZ,
    offset: struct { x: u32, y: u32 },
};

pub const RendererType = enum { Auto, HW, SW };

pub const Pin = struct {
    lat: f64,
    lon: f64,
    handle: ?[:0]const u8 = null,
    category: enum { Instructive, Structural } = .Instructive,
    metadata: std.array_hash_map.StringArrayHashMap([:0]const u8),
};
pub const PinGroup = struct {
    pins: std.ArrayList(Pin),
    ordered: bool = false,
    color: u24 = 0x000000,
};

pub const UIButton = struct {
    text: [:0]const u8,
    jsonapi_click_single: [:0]const u8,
    jsonapi_click_hold: [:0]const u8,
    only_visible_when_pin_active: bool,
    only_visible_when_sync_shellpipe: bool = false,
    group_number: ?u8,
};

pub const MepoArgTag = enum { Text, Number, Exps };
pub const MepoArg = union(MepoArgTag) { Text: [:0]const u8, Number: f64, Exps: []const u8 };

pub const MepoFnNargs = 6;

pub const MepoFnSpecArg = struct {
    name: []const u8,
    tag: MepoArgTag,
    desc: []const u8,
    default_value: ?MepoArg = null,
};
pub const MepoFnSpec = struct {
    name: []const u8,
    desc: []const u8,
    args: []const MepoFnSpecArg,
    execute: *const fn (mepo: *Mepo, args: [MepoFnNargs]MepoArg) anyerror!void,
};

pub const KeyInput = struct { key: u8, keymod: sdl.SDL_Keymod };
pub const ClickInput = struct { button: u8, clicks: i8 };
pub const GestureInputAction = enum { Pan, Rotate };
pub const GestureInputDirection = enum { In, Out };
pub const GestureInput = struct { action: GestureInputAction, direction: GestureInputDirection, n_fingers: u8 };
pub const TimerInput = struct { interval_seconds: u32, created_at_ticks: u32 };

pub const Pending = enum { None, Redraw, Drag };

pub const Color = struct {
    value: u24 = 0x000000,
    opacity: u8 = 255,

    const RGBA = packed struct { r: u8, g: u8, b: u8, a: u8 };

    fn to_rgba(self: @This()) RGBA {
        return .{
            .r = @intCast(self.value >> 16),
            .g = @intCast(self.value >> 8 & 0xff),
            .b = @intCast(self.value & 0xff),
            .a = self.opacity,
        };
    }

    pub fn to_sdl(self: @This()) sdl.SDL_Color {
        const rgba = self.to_rgba();
        return .{ .r = rgba.r, .g = rgba.g, .b = rgba.b, .a = rgba.a };
    }

    pub fn to_u32(self: @This()) u32 {
        return @bitCast(self.to_rgba());
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

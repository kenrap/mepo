const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");
const p = @import("../util/utilprefs.zig");

pub const spec = types.MepoFnSpec{
    .name = "clippaste",
    .desc = "Extract clipboard contents and either center on coordinate (if clipboard content matches `lat lon` format); otherwise run clipboard contents as JSON API expressions.",
    .args = &.{},
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    const text_c = sdl.SDL_GetClipboardText();
    const text = try std.fmt.allocPrint(mepo.allocator, "{s}", .{text_c});
    defer mepo.allocator.free(text);
    defer sdl.SDL_free(text_c);

    // Try and parse lat lon by looking at first two space seperated tokens
    // trim commas, and see if can parse as floats; if so assume lat/lon
    // if not - break out and run whatever is in clipboard as jsonapi
    parse_lat_lon: {
        var it = std.mem.splitSequence(u8, text, " ");
        var lat: ?f64 = null;
        var lon: ?f64 = null;

        if (it.next()) |item| {
            const trimmed = std.mem.trim(u8, item, ",");
            const l = std.fmt.parseFloat(f64, trimmed) catch break :parse_lat_lon;
            lat = l;
        }
        if (it.next()) |item| {
            const trimmed = std.mem.trim(u8, item, ",");
            const l = std.fmt.parseFloat(f64, trimmed) catch break :parse_lat_lon;
            lon = l;
        }

        if (lat == null or lon == null) break :parse_lat_lon;
        p.set_n(p.pref.lat, lat.?);
        p.set_n(p.pref.lon, lon.?);
        return;
    }

    // If not coordinates; run whatever is in clipboards as jsonapi expression
    try mepo.jsonapi_execute(text);
}

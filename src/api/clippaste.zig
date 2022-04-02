const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");

pub const spec = .{
    .name = "clippaste",
    .args = (&[_]types.MepoArgTag{})[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    const text_c = sdl.SDL_GetClipboardText();
    const text = try std.fmt.allocPrint(mepo.allocator, "{s}", .{text_c});
    defer mepo.allocator.free(text);
    defer sdl.SDL_free(text_c);

    // Try and parse lat lon by looking at first two space seperated tokens
    // trim commas, and see if can parse as floats; if so assume lat/lon
    // if not - break out and run whatever is in clipboard as mepolang
    parse_lat_lon: {
        var it = std.mem.split(u8, text, " ");
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
        mepo.lat = lat.?;
        mepo.lon = lon.?;
        return;
    }


}

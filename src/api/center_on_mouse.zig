const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const p = @import("../util/utilprefs.zig");

pub const spec = types.MepoFnSpec{
    .name = "center_on_mouse",
    .desc = "Center the map on the current position of the mouse.",
    .args = &.{},
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    const latlon = mepo.cursor_latlon();
    p.set_n(p.pref.lat, latlon.Lat);
    p.set_n(p.pref.lon, latlon.Lon);
}

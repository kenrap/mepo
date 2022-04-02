const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");

pub const spec = .{
    .name = "clipcopy",
    .args = (&[_]types.MepoArgTag{})[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    const copy_text = try std.fmt.allocPrintZ(
        mepo.allocator,
        "{d:.5}, {d:.5}",
        .{mepo.lat, mepo.lon},
    );

    try utilsdl.errorcheck(sdl.SDL_SetClipboardText(copy_text));
}

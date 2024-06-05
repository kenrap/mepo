const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");
const p = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "clipcopy",
    .desc = "Copy the current map coordinates to the clipboard; will be in format: `lat lon`.",
    .args = &.{},
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    const copy_text = try std.fmt.allocPrintZ(
        mepo.allocator,
        "{d:.5}, {d:.5}",
        .{ p.get(p.pref.lat).f, p.get(p.pref.lon).f },
    );
    defer mepo.allocator.free(copy_text);
    try utilsdl.errorcheck(sdl.SDL_SetClipboardText(&copy_text[0]));
}

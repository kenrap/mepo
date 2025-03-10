const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub const spec = types.MepoFnSpec{
    .name = "bind_click",
    .desc = "Bind a particular number of successive clicks to run a JSON API expressions.",
    .args = &.{
        .{ .tag = .Number, .name = "button", .desc = "Mousebutton to bind (`1` = left, `2` = right, `3` = middle)" },
        .{ .tag = .Number, .name = "clicks", .desc = "Number of successive clicks to trigger action" },
        .{ .tag = .Exps, .name = "exps", .desc = "JSON API expressions to run" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try bind_click(mepo, @intFromFloat(args[0].Number), @intFromFloat(args[1].Number), args[2].Exps);
}

fn bind_click(mepo: *Mepo, button: u8, clicks: i8, expression: []const u8) !void {
    utildbg.log("Binding click: button={d} clicks={d} to expression {s}\n", .{ button, clicks, expression });

    const sdl_button: u8 = if (button == 1) sdl.SDL_BUTTON_LEFT else sdl.SDL_BUTTON_RIGHT;
    const click = types.ClickInput{ .button = sdl_button, .clicks = clicks };

    if (mepo.table_clicks.get(click)) |heap_str| {
        mepo.allocator.free(heap_str);
        _ = mepo.table_clicks.swapRemove(click);
    }
    const expression_mepo_allocated = try mepo.allocator.dupe(u8, expression);
    try mepo.table_clicks.put(click, expression_mepo_allocated);
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .name = "bind_click",
    .args = (&[_]types.MepoFnSpecArg{
        .{.tag = .Number, .name = "button"},
        .{.tag = .Number, .name = "clicks"},
        .{.tag = .Text, .name = "mepolang_expression"},
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const button = @floatToInt(u8, args[0].Number);
    const clicks = @floatToInt(i8, args[1].Number);
    const expression = args[2].Text;
    try bind_click(mepo, button, clicks, expression);
}

fn bind_click(mepo: *Mepo, button: u8, clicks: i8, expression: []const u8) !void {
    utildbg.log("Binding click: button={d} clicks={d} to expression {s}\n", .{ button, clicks, expression });

    const sdl_button: u8 = if (button == 1) sdl.SDL_BUTTON_LEFT else sdl.SDL_BUTTON_RIGHT;
    const click = .{ .button = sdl_button, .clicks = clicks };

    if (mepo.table_clicks.get(click)) |heap_str| {
        mepo.allocator.free(heap_str);
        _ = mepo.table_clicks.swapRemove(click);
    }
    const expression_mepo_allocated = try mepo.allocator.dupe(u8, expression);
    try mepo.table_clicks.put(click, expression_mepo_allocated);
}

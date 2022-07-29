const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .name = "bind_quit",
    .desc = "Bind a mepolang expression to run on quitting the application",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "mepolang_expression", .desc = "Mepolang expression to run" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const expression = args[0].Text;
    try bind_quit(mepo, expression);
}

fn bind_quit(mepo: *Mepo, expression: []const u8) !void {
    if (mepo.quit_action) |quit_action| mepo.allocator.free(quit_action);
    mepo.quit_action = try mepo.allocator.dupe(u8, expression);
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub fn f_bind_button(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const text = args[0].Text;
    const expression = args[1].Text;
    try bind_button(mepo, text, expression);
}

fn bind_button(mepo: *Mepo, text: []const u8, expression: []const u8) !void {
    utildbg.log("Binding button: text=<{s}> expression=<{d}>\n", .{ text, expression });

    for (mepo.uibuttons.items) |*btn| {
        if (std.mem.eql(u8, text, btn.text)) {
            mepo.allocator.free(btn.mepolang);
            btn.mepolang = try mepo.allocator.dupeZ(u8, expression);
            return;
        }
    }

    try mepo.uibuttons.append(.{
        .text = try mepo.allocator.dupeZ(u8, text),
        .mepolang = try mepo.allocator.dupeZ(u8, expression),
    });
}

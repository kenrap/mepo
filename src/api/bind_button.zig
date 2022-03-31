const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");
const utilarg = @import("../util/utilarg.zig");

pub const spec = .{
    .args = (&[_]types.MepoArgTag{ .Number, .Text, .Text })[0..],
};

pub fn f_bind_button(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    _ = utilarg.validate_args(spec, args) catch |e| return e;

    const visible_only_when_has_pins = args[0].Number == 1;
    const text = args[1].Text;
    const expression = args[2].Text;
    try bind_button(mepo, visible_only_when_has_pins, text, expression);
}

fn bind_button(mepo: *Mepo, visible_only_when_has_pins: bool, text: []const u8, expression: []const u8) !void {
    utildbg.log("Binding button: text=<{s}> expression=<{d}>\n", .{ text, expression });

    for (mepo.uibuttons.items) |*btn| {
        if (std.mem.eql(u8, text, btn.text)) {
            mepo.allocator.free(btn.mepolang);
            btn.mepolang = try mepo.allocator.dupeZ(u8, expression);
            btn.only_visible_when_has_pins = visible_only_when_has_pins;
            return;
        }
    }

    try mepo.uibuttons.append(.{
        .text = try mepo.allocator.dupeZ(u8, text),
        .mepolang = try mepo.allocator.dupeZ(u8, expression),
        .only_visible_when_has_pins = visible_only_when_has_pins,
    });
}

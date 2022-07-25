const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .name = "bind_button",
    .desc = "Create a UI button which executes a mepolang action",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "visible_only_when_has_pins", .desc = "Set to 1 to only show buton *if* there are visible pins" },
        .{ .tag = .Text, .name = "button_text", .desc = "Text that will be shown on the button" },
        .{ .tag = .Text, .name = "mepolang_expression", .desc = "Mepolang expression to run on clicking the button" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
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

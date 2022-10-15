const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .name = "bind_button",
    .desc = "Create a UI button which executes a mepolang action. UI buttons appear aligned in the bottom right of the screen in the button bar.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "visible_only_when_has_pins", .desc = "Set to `1` to only show button *if* there are visible pins" },
        .{ .tag = .Number, .name = "group_number", .desc = "Group number (0-9) to associate with button. Background will match group and button will highlight when group active. Use -1 for no associated group." },
        .{ .tag = .Text, .name = "button_text", .desc = "Text that will be shown on the button" },
        .{ .tag = .Text, .name = "mepolang_expression_single_click", .desc = "Mepolang expression to run on single clicking the button" },
        .{ .tag = .Text, .name = "mepolang_expression_double_click", .desc = "Mepolang expression to run on double clicking the button" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const visible_only_when_has_pins = args[0].Number == 1;
    const group_number = if (args[1].Number < 0) null else @floatToInt(u8, args[1].Number);
    const text = args[2].Text;
    const expression_click_single = args[3].Text;
    const expression_click_double = args[4].Text;
    try bind_button(mepo, visible_only_when_has_pins, group_number, text, expression_click_single, expression_click_double);
}

fn bind_button(mepo: *Mepo, visible_only_when_has_pins: bool, group_number: ?u8, text: []const u8, expression_click_single: []const u8, expression_click_double: []const u8) !void {
    utildbg.log("Binding button: text=<{s}> 1 click=<{s}> 2 clicks=<{s}>\n", .{ text, expression_click_single, expression_click_double });

    for (mepo.uibuttons.items) |*btn| {
        if (std.mem.eql(u8, text, btn.text)) {
            mepo.allocator.free(btn.mepolang_click_single);
            mepo.allocator.free(btn.mepolang_click_double);
            btn.mepolang_click_single = try mepo.allocator.dupeZ(u8, expression_click_single);
            btn.mepolang_click_double = try mepo.allocator.dupeZ(u8, expression_click_double);
            btn.only_visible_when_has_pins = visible_only_when_has_pins;
            return;
        }
    }

    try mepo.uibuttons.append(.{
        .text = try mepo.allocator.dupeZ(u8, text),
        .group_number = group_number,
        .mepolang_click_single = try mepo.allocator.dupeZ(u8, expression_click_single),
        .mepolang_click_double = try mepo.allocator.dupeZ(u8, expression_click_double),
        .only_visible_when_has_pins = visible_only_when_has_pins,
    });
}

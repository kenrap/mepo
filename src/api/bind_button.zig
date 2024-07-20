const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .name = "bind_button",
    .desc = "Create a UI button which executes a JSON commands. UI buttons appear aligned in the bottom right of the screen or the top left alongside the pin details overlay (see first argument).",
    .args = &.{
        .{ .tag = .Number, .name = "pin_only", .desc = "Set to `1` to only show button in top bar *if* there is a currently activated pin.", .default_value = .{ .Number = 0 } },
        .{ .tag = .Number, .name = "group", .desc = "Group number (`0`-`9`) to associate with button. A Colorbar will match group # and button will highlight when group active. Use `-1` for no associated group.", .default_value = .{ .Number = -1 } },
        .{ .tag = .Text, .name = "text", .desc = "Text that will be shown on the button" },
        .{ .tag = .Exps, .name = "exps_click", .desc = "JSON API expressions to run on single clicking the button", .default_value = .{ .Exps = "[]"} },
        .{ .tag = .Exps, .name = "exps_hold", .desc = "JSON API expressions to run on holding the button", .default_value = .{ .Exps = "[]"} },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const visible_only_when_pin_active = args[0].Number == 1;
    const group_number = if (args[1].Number < 0) null else @as(u8, @intFromFloat(args[1].Number));
    const text = args[2].Text;
    const expression_click_single = args[3].Exps;
    const expression_click_hold = args[4].Exps;
    try bind_button(mepo, visible_only_when_pin_active, group_number, text, expression_click_single, expression_click_hold);
}

fn bind_button(mepo: *Mepo, visible_only_when_pin_active: bool, group_number: ?u8, text: []const u8, expression_click_single: []const u8, expression_click_hold: []const u8) !void {
    utildbg.log("Binding button: text=<{s}> 1 click=<{s}> 2 clicks=<{s}>\n", .{ text, expression_click_single, expression_click_hold });

    for (mepo.uibuttons.items) |*btn| {
        if (std.mem.eql(u8, text, btn.text)) {
            mepo.allocator.free(btn.jsonapi_click_single);
            mepo.allocator.free(btn.jsonapi_click_hold);
            btn.jsonapi_click_single = try mepo.allocator.dupeZ(u8, expression_click_single);
            btn.jsonapi_click_hold = try mepo.allocator.dupeZ(u8, expression_click_hold);
            btn.only_visible_when_pin_active = visible_only_when_pin_active;
            return;
        }
    }

    try mepo.uibuttons.append(.{
        .text = try mepo.allocator.dupeZ(u8, text),
        .group_number = group_number,
        .jsonapi_click_single = try mepo.allocator.dupeZ(u8, expression_click_single),
        .jsonapi_click_hold = try mepo.allocator.dupeZ(u8, expression_click_hold),
        .only_visible_when_pin_active = visible_only_when_pin_active,
    });
}

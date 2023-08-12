const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const p = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "pin_cycle",
    .desc = "Cycle the currently focused pin group pin.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Number, .name = "viewport_only", .desc = "Use `1` to only cycle between pins in viewport" },
        .{ .tag = .Number, .name = "delta", .desc = "Delta amount (positive or negative) for number of pins to skip" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try pin_cycle(mepo, @as(i32, @intFromFloat(args[0].Number)) == 1,
        @intFromFloat(args[1].Number));
}

pub fn pin_cycle(mepo: *Mepo, viewport_only: bool, delta: i32) !void {
    const active_group = mepo.pin_groups[mepo.pin_group_active].items;
    if (active_group.len == 0) return;

    var target_i = if (mepo.pin_group_active_item) |active_item| @as(i32, @intCast(active_item)) else 0;
    const group_unordered = !p.get(p.pingroup_prop(mepo.pin_group_active, .Ordered)).b;
    const add: i32 = if (delta > 0) 1 else -1;
    for (0..std.math.absCast(delta)) |_| {
        var pin_i = target_i + add;
        // E.g. two conditions to skip and continually increase pin_i:
        // 1. Within an ordered group, structural pins should be skipped
        // 2. Requested to cycle only viewport visible pins, non visible pins skipped
        while (pin_i >= 0 and pin_i < active_group.len) {
            const unstructural = active_group[@intCast(pin_i)].category != .Structural;
            const visible = !viewport_only or pin_in_viewport(mepo, pin_i);
            if ((group_unordered or unstructural) and visible) {
                target_i = @intCast(pin_i);
                break;
            }
            pin_i += add;
        }
    }

    if (mepo.pin_group_active_item == null or mepo.pin_group_active_item.? != target_i) {
        mepo.pin_group_active_item = @intCast(target_i);
        mepo.blit_pinlayer_cache.clearAndFree();
    }
}

fn pin_in_viewport(mepo: *Mepo, pin_index: i32) bool {
    const pin = mepo.pin_groups[mepo.pin_group_active].items[@intCast(pin_index)];
    const x = mepo.convert_latlon_to_xy(.LonToX, pin.lon);
    const y = mepo.convert_latlon_to_xy(.LatToY, pin.lat);
    return x > 0 and x < mepo.win_w and y > 0 and y < mepo.win_h;
}

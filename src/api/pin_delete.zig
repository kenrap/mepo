const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_delete",
    .desc = "Delete a pin by its handle.",
    .args = &.{
        .{ .tag = .Number, .name = "group", .desc = "Optional group number (if unset uses the current group)", .default_value = .{ .Number = -1 } },
        .{ .tag = .Text, .name = "handle", .desc = "Optional pin handle to delete (if unset uses the current pin)", .default_value = .{ .Text = "" } },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try pin_delete(mepo, @intFromFloat(args[0].Number), args[1].Text);
}

fn pin_delete(mepo: *Mepo, group: i32, handle: [:0]const u8) !void {
    defer mepo.blit_pinlayer_cache.clearAndFree();

    const pin_group: usize = if (group < 0) mepo.pin_group_active else @intCast(group);
    const target_pin_i = target_pin_i: {
        if (handle.len == 0) {
            if (mepo.pin_group_active_item) |active_item| {
                break :target_pin_i active_item;
            }
        } else {
            for (mepo.pin_groups[pin_group].items, 0..) |pin, pin_i| {
                if (pin.handle) |pin_handle| {
                    if (std.mem.eql(u8, handle, pin_handle)) {
                        break :target_pin_i pin_i;
                    }
                }
            }
        }
        return;
    };

    // Free up handle string
    mepo.allocator.free(mepo.pin_groups[pin_group].items[target_pin_i].handle.?);

    // Free up metadata strings
    var it = mepo.pin_groups[pin_group].items[target_pin_i].metadata.iterator();
    while (it.next()) |kv| {
        mepo.allocator.free(kv.key_ptr.*);
        mepo.allocator.free(kv.value_ptr.*);
    }

    // If deleting currently active pin, clear out the active item index as well
    if (pin_group == mepo.pin_group_active) {
        if (mepo.pin_group_active_item) |active_pin_item| {
            if (active_pin_item == target_pin_i) {
                mepo.pin_group_active_item = null;
            }
        }
    }
    _ = mepo.pin_groups[pin_group].orderedRemove(target_pin_i);
}

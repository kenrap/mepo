const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub const spec = .{
    .name = "pin_purge",
    .desc = "Purge all pins in the currently active pin group.",
    .args = &.{},
    .execute = execute,
};

fn execute(mepo: *Mepo, _: [types.MepoFnNargs]types.MepoArg) !void {
    mepo.pin_group_active_item = null;
    defer mepo.blit_pinlayer_cache.clearAndFree();

    for (mepo.pin_groups[mepo.pin_group_active].items) |p| {
        if (p.handle != null) {
            mepo.allocator.free(p.handle.?);

            // Free up metadata strings
            var it = p.metadata.iterator();
            while (it.next()) |kv| {
                mepo.allocator.free(kv.key_ptr.*);
                mepo.allocator.free(kv.value_ptr.*);
            }
        }
    }
    mepo.pin_groups[mepo.pin_group_active].clearAndFree();
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");
const utildbg = @import("../util/utildbg.zig");

pub const spec = .{
    .name = "bind_key",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "modifier" },
        .{ .tag = .Text, .name = "key" },
        .{ .tag = .Text, .name = "mepolang_expression" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const modifier = args[0].Text;
    const key = args[1].Text;
    const expression = args[2].Text;
    try bind_key(mepo, modifier, key, expression);
}

fn bind_key(mepo: *Mepo, mod_str: [:0]const u8, key_str: [:0]const u8, expression: []const u8) !void {
    utildbg.log("Binding key: mod={s} code={s} to expression {s}\n", .{ mod_str, key_str, expression });

    // Keymod
    const keymod = m: {
        var modifier = sdl.KMOD_NONE;
        for (mod_str) |character| {
            modifier |= switch (character) {
                'c' => sdl.KMOD_CTRL,
                's' => sdl.KMOD_SHIFT,
                'a' => sdl.KMOD_ALT,
                else => 0,
            };
        }
        break :m modifier;
    };

    const key: types.KeyInput = .{
        .keymod = @intCast(c_uint, keymod),
        .key = std.ascii.toLower(key_str[0]),
    };

    if (mepo.table_keybindings.get(key)) |heap_str| {
        mepo.allocator.free(heap_str);
        _ = mepo.table_keybindings.swapRemove(key);
    }
    const expression_mepo_allocated = try mepo.allocator.dupe(u8, expression);
    try mepo.table_keybindings.put(key, expression_mepo_allocated);
}

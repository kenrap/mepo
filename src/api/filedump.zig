const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilfile = @import("../util/utilfile.zig");
const utilprefs = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "filedump",
    .desc = "Save the current state of all preferences to a file.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "filepath", .desc = "Path to file to save state to" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const filepath = args[0].Text;
    try filedump(mepo, filepath);
}

fn filedump(mepo: *Mepo, filepath: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    const expanded_path = try utilfile.wordexp_filepath(arena.allocator(), filepath);
    try utilfile.mkdirp_folder_basename(expanded_path);
    const mepolang_file = try std.fs.createFileAbsoluteZ(expanded_path, .{});
    defer mepolang_file.close();

    var lines = std.ArrayList([]const u8).init(arena.allocator());

    // 1. Preferences
    for (utilprefs.prefs_mapping) |pref| {
        var is_text = false;
        const numerical_val : f64 = switch (pref.value) {
          .b => @intToFloat(f64, @boolToInt(pref.value.b)),
          .u => @intToFloat(f64, pref.value.u),
          .f => pref.value.f,
          .t => v: { is_text = true; break :v -1; },
        };
        const prefset_statement = statement: {
            if (is_text) {
                break :statement try std.fmt.allocPrint(arena.allocator(), "prefset_t {s} [{s}];", .{pref.name, pref.value.t});
            } else {
                break :statement try std.fmt.allocPrint(arena.allocator(), "prefset_n {s} {d:0.02};", .{pref.name, numerical_val});
            }
        };
        try lines.append(prefset_statement);
    }

    // 2. Bind_button table
    // 3. Bind_gesture table
    // 4. Bind_click table
    // 5. Bind_key table
    // 6. Bind_signal table

    // 7. Pins data
    for (mepo.pin_groups) |pg, pg_i| {
        for (pg.pins.items) |pin| {
            const statement_pin_add = try std.fmt.allocPrint(
                arena.allocator(),
                "pin_add {d} {d} {d:.4} {d:.4} [{s}] [{s}];",
                .{
                    pg_i + 1, 
                    @as(f64, if (pin.category == .Structural) 1.0 else 0.0),
                    pin.lat,
                    pin.lon,
                    pin.handle,
                    pin.name,
                },
            );
            try lines.append(statement_pin_add);
        }
    }

    // 8. TODO: need to rework pin_groups to be reworked into (1) prefs

    const file_data = try std.mem.join(arena.allocator(), "\n", lines.items);
    try mepolang_file.writeAll(file_data);
}

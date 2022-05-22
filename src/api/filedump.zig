const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilfile = @import("../util/utilfile.zig");
const utilprefs = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "filedump",
    .desc = "Save the current state of all preferences to a file.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "datatypes", .desc = "Types of data to save (p = pins, r = preferences, b = bindings); ex. 'pr' would save both pins and preferences but not bindings" },
        .{ .tag = .Text, .name = "filepath", .desc = "Path to file to save state to" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const save_types = args[0].Text;
    const filepath = args[1].Text;
    try filedump(mepo, save_types, filepath);
}

fn filedump(mepo: *Mepo, save_types: []const u8, filepath: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    const expanded_path = try utilfile.wordexp_filepath(arena.allocator(), filepath);
    try utilfile.mkdirp_folder_basename(expanded_path);
    const mepolang_file = try std.fs.createFileAbsoluteZ(expanded_path, .{});
    defer mepolang_file.close();
    var lines = std.ArrayList([]const u8).init(arena.allocator());

    // 1. Preferences
    if (std.mem.containsAtLeast(u8, save_types, 1, "r")) {
        for (utilprefs.prefs_mapping) |pref| {
            var format_as : enum { Text, HexText, Number } = .Number;

            const numerical_val : f64 = switch (pref.value) {
              .b => @intToFloat(f64, @boolToInt(pref.value.b)),
              .u => @intToFloat(f64, pref.value.u),
              .u24 => v: { format_as = .HexText; break :v -1; },
              .f => pref.value.f,
              .t => v: { format_as = .Text; break :v -1; },
            };
            const prefset_statement = statement: {
                if (format_as == .Text) {
                    break :statement try std.fmt.allocPrint(arena.allocator(), "prefset_t {s} [{s}];", .{pref.name, pref.value.t});
                } else if (format_as == .Number) {
                    break :statement try std.fmt.allocPrint(arena.allocator(), "prefset_n {s} {d:0.02};", .{pref.name, numerical_val});
                } else if (format_as == .HexText) {
                    break :statement try std.fmt.allocPrint(arena.allocator(), "prefset_t {s} #{x};", .{pref.name, pref.value.u24});
                } else {
                    break :statement "";
                }
            };
            try lines.append(prefset_statement);
        }
    }

    // 2. Bindings
    if (std.mem.containsAtLeast(u8, save_types, 1, "b")) {
        // - TODO: Bind_button table
        // - TODO: Bind_gesture table
        // - TODO: Bind_click table
        // - TODO: Bind_key table
        // - TODO: Bind_signal table
    }

    // 3. Pins data
    if (std.mem.containsAtLeast(u8, save_types, 1, "p")) {
        for (mepo.pin_groups) |pg, pg_i| {
            for (pg.items) |pin| {
                const is_structural : u32 = b: {
                    if (pin.category == .Structural) break :b 1;
                    break :b 0;
                };
                const statement_pin_add = try std.fmt.allocPrint(
                    arena.allocator(),
                    "pin_add {d} {d} {d:.4} {d:.4} [{s}] [{s}];",
                    .{ pg_i, is_structural, pin.lat, pin.lon, pin.handle, pin.name },
                );
                try lines.append(statement_pin_add);

                var it = pin.metadata.iterator();
                while (it.next()) |kv| {
                    const statement_meta = try std.fmt.allocPrint(
                        arena.allocator(),
                        "pin_meta {d} [{s}] [{s}] [{s}];",
                        .{ pg_i, pin.handle, kv.key_ptr.*, kv.value_ptr.* },
                    );
                    try lines.append(statement_meta);
                }
            }
        }
    }

    const file_data = try std.mem.join(arena.allocator(), "\n", lines.items);
    try mepolang_file.writeAll(file_data);
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");

const utilfile = @import("../util/utilfile.zig");
const utilsdl = @import("../util/utilsdl.zig");
const utilprefs = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "filedump",
    .desc = "Save the current state of pins, preference, and/or bindings to a file as mepolang.",
    .args = &.{
        .{ .tag = .Text, .name = "datatypes", .desc = "Types of data to save (`p` = pins, `r` = preferences, `b` = bindings); ex. `pr` would save both pins and preferences but not bindings" },
        .{ .tag = .Text, .name = "filepath", .desc = "Path to file to save state to" },
    },
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

    const Statement = struct {
        cmd: [:0]const u8,
        args: std.json.ArrayHashMap(std.json.Value),
    };
    var statements = std.ArrayList(Statement).init(arena.allocator());

    // 1. Preferences
    if (std.mem.containsAtLeast(u8, save_types, 1, "r")) {
        for (utilprefs.prefs_mapping) |pref| {
            const format_as: enum { Text, HexText, Number } = switch (pref.value) {
                .t => .Text,
                .b => .Number,
                .u => .Number,
                .f => .Number,
                .u24 => .HexText
            };
            if (format_as == .Text) {
                var args = std.StringArrayHashMap(std.json.Value).init(arena.allocator());
                try args.put("pref", .{ .string = pref.name });
                try args.put("value", .{ .string = if (pref.value.t) |tv| tv else "" });
                try statements.append(.{
                  .cmd = "prefset_t",
                  .args = try std.json.ArrayHashMap(std.json.Value).jsonParseFromValue(arena.allocator(), .{.object = args}, .{})
                });
            } else if (format_as == .Number) {
                var args = std.StringArrayHashMap(std.json.Value).init(arena.allocator());
                try args.put("pref", .{ .string = pref.name });
                try args.put("value", .{ .float = switch (pref.value) {
                    .b => @floatFromInt(@intFromBool(pref.value.b)),
                    .u => @floatFromInt(pref.value.u),
                    .f => pref.value.f,
                    else => unreachable
                }});
                try statements.append(.{
                  .cmd = "prefset_n",
                  .args = try std.json.ArrayHashMap(std.json.Value).jsonParseFromValue(arena.allocator(), .{.object = args}, .{})
                });
            } else if (format_as == .HexText) {
                var args = std.StringArrayHashMap(std.json.Value).init(arena.allocator());
                try args.put("pref", .{ .string = pref.name });
                try args.put("value", .{ .string = try std.fmt.allocPrint(arena.allocator(), "#{x}", .{pref.value.u24}) });
                try statements.append(.{
                  .cmd = "prefset_t",
                  .args = try std.json.ArrayHashMap(std.json.Value).jsonParseFromValue(arena.allocator(), .{.object = args}, .{})
                });
            }
        }
    }

    // 2. Bindings
   // if (std.mem.containsAtLeast(u8, save_types, 1, "b")) {
   //     try lines.append("\n# Bindings;");

   //     // Gestures
   //     var it_gestures = mepo.table_gestures.iterator();
   //     while (it_gestures.next()) |gest| {
   //         const direction: i8 = if (gest.key_ptr.*.direction == .In) 1 else -1;
   //         const act = if (gest.key_ptr.*.action == .Pan) "pan   " else "rotate";
   //         const statement_gest = try std.fmt.allocPrint(
   //             arena.allocator(),
   //             "bind_gesture {s} {d} {d} [{s}];",
   //             .{ act, gest.key_ptr.*.n_fingers, direction, gest.value_ptr.* },
   //         );
   //         try lines.append(statement_gest);
   //     }

   //     // Clicks
   //     var it_clicks = mepo.table_clicks.iterator();
   //     while (it_clicks.next()) |click| {
   //         const btn: u8 = if (click.key_ptr.*.button == sdl.SDL_BUTTON_LEFT) 1 else 2;
   //         const statement_click = try std.fmt.allocPrint(
   //             arena.allocator(),
   //             "bind_click {d} {d} [{s}];",
   //             .{ btn, click.key_ptr.*.clicks, click.value_ptr.* },
   //         );
   //         try lines.append(statement_click);
   //     }

   //     // Signals
   //     var it_sigs = mepo.table_signals.iterator();
   //     while (it_sigs.next()) |sig| {
   //         const signame = switch (sig.key_ptr.*) {
   //             std.os.linux.SIG.USR1 => "USR1",
   //             std.os.linux.SIG.USR2 => "USR2",
   //             std.os.linux.SIG.INT => "INT",
   //             std.os.linux.SIG.TERM => "TERM",
   //             else => continue,
   //         };

   //         const statement_signal = try std.fmt.allocPrint(
   //             arena.allocator(),
   //             "bind_signal {s} [{s}];",
   //             .{ signame, sig.value_ptr.* },
    //        );
    //        try lines.append(statement_signal);
    //    }

    //    // Timers
    //    var it_timers = mepo.table_timers.iterator();
    //    while (it_timers.next()) |sig| {
    //        const statement_timer = try std.fmt.allocPrint(
    //            arena.allocator(),
    //            "bind_timer {d} [{s}];",
    //            .{ sig.key_ptr.*.interval_seconds, sig.value_ptr.* },
    //        );
    //        try lines.append(statement_timer);
    //    }

    //    // Keybindings
    //    var it_keys = mepo.table_keybindings.iterator();
    //    while (it_keys.next()) |key| {
    //        const keymod = utilsdl.sdl_keymod_to_str(key.key_ptr.keymod);
    //        const statement_signal = try std.fmt.allocPrint(
    //            arena.allocator(),
    //            "bind_key [{s}] [{c}] [{s}];",
    //            .{ keymod, key.key_ptr.*.key, key.value_ptr.* },
    //        );
    //        try lines.append(statement_signal);
    //    }

    //    // UI Buttons
    //    for (mepo.uibuttons.items) |btn| {
    //        const pins_only_btn: u8 = if (btn.only_visible_when_pin_active) 1 else 0;
    //        const group_number: i8 = if (btn.group_number) |g| @intCast(g) else -1;
    //        const statement_button = try std.fmt.allocPrint(
    //            arena.allocator(),
    //            "bind_button {d} {d} [{s}] [{s}] [{s}];",
    //            .{ pins_only_btn, group_number, btn.text, btn.mepolang_click_single, btn.mepolang_click_hold },
    //        );
    //        try lines.append(statement_button);
    //    }
    //}

    // 3. Pins data
    //if (std.mem.containsAtLeast(u8, save_types, 1, "p")) {
    //    try lines.append("\n# Pins;");

    //    for (mepo.pin_groups, 0..) |pg, pg_i| {
    //        for (pg.items) |pin| {
    //            const is_structural: u32 = b: {
    //                if (pin.category == .Structural) break :b 1;
    //                break :b 0;
    //            };
    //            const handle: [:0]const u8 = handle: {
    //                if (pin.handle) |h| break :handle h;
    //                break :handle "";
    //            };
    //            const statement_pin_add = try std.fmt.allocPrint(
    //                arena.allocator(),
    //                "pin_add {d} {d} {d:.4} {d:.4} [{s}];",
    //                .{ pg_i, is_structural, pin.lat, pin.lon, handle },
    //            );
    //            try lines.append(statement_pin_add);

    //            var it = pin.metadata.iterator();
    //            while (it.next()) |kv| {
    //                const statement_meta = try std.fmt.allocPrint(
    //                    arena.allocator(),
    //                    "pin_meta {d} [{s}] [{s}] [{s}];",
    //                    .{ pg_i, handle, kv.key_ptr.*, kv.value_ptr.* },
    //                );
    //                try lines.append(statement_meta);
    //            }
    //        }
    //    }

    //    // Activate current pingroup
    //    try lines.append(try std.fmt.allocPrint(
    //        arena.allocator(),
    //        "pin_groupactivate {d};",
    //        .{mepo.pin_group_active},
    //    ));
    //}

    const str = try std.json.stringifyAlloc(arena.allocator(), statements.items, .{
        .whitespace = .indent_2,
    });
    try mepolang_file.writeAll(str);
}

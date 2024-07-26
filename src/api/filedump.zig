const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const sdl = @import("../sdlshim.zig");

const utilfile = @import("../util/utilfile.zig");
const utilsdl = @import("../util/utilsdl.zig");
const utilprefs = @import("../util/utilprefs.zig");

pub const spec = .{
    .name = "filedump",
    .desc = "Save the current state of pins and/or preferences to a file as JSON API expressions.",
    .args = &.{
        .{ .tag = .Text, .name = "datatypes", .desc = "Types of data to save (`p` = pins, `r` = prefsets); ex. `pr` would save both pins and preferences" },
        .{ .tag = .Text, .name = "filepath", .desc = "Path to file to save state to" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const save_types = args[0].Text;
    const filepath = args[1].Text;
    try filedump(mepo, save_types, filepath);
}

pub fn filedump(mepo: *Mepo, save_types: []const u8, filepath: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    const expanded_path = try utilfile.wordexp_filepath(arena.allocator(), filepath);
    try utilfile.mkdirp_folder_basename(expanded_path);
    const jsonapi_file = try std.fs.createFileAbsoluteZ(expanded_path, .{});
    defer jsonapi_file.close();

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
                .u24 => .HexText,
            };
            if (format_as == .Text) {
                var args = std.StringArrayHashMap(std.json.Value).init(arena.allocator());
                try args.put("pref", .{ .string = pref.name });
                try args.put("value", .{ .string = if (pref.value.t) |tv| tv else "" });
                try statements.append(.{ .cmd = "prefset_t", .args = try std.json.ArrayHashMap(std.json.Value).jsonParseFromValue(arena.allocator(), .{ .object = args }, .{}) });
            } else if (format_as == .Number) {
                var args = std.StringArrayHashMap(std.json.Value).init(arena.allocator());
                try args.put("pref", .{ .string = pref.name });
                try args.put("value", .{ .float = switch (pref.value) {
                    .b => @floatFromInt(@intFromBool(pref.value.b)),
                    .u => @floatFromInt(pref.value.u),
                    .f => pref.value.f,
                    else => unreachable,
                } });
                try statements.append(.{ .cmd = "prefset_n", .args = try std.json.ArrayHashMap(std.json.Value).jsonParseFromValue(arena.allocator(), .{ .object = args }, .{}) });
            } else if (format_as == .HexText) {
                var args = std.StringArrayHashMap(std.json.Value).init(arena.allocator());
                try args.put("pref", .{ .string = pref.name });
                try args.put("value", .{ .string = try std.fmt.allocPrint(arena.allocator(), "#{x}", .{pref.value.u24}) });
                try statements.append(.{ .cmd = "prefset_t", .args = try std.json.ArrayHashMap(std.json.Value).jsonParseFromValue(arena.allocator(), .{ .object = args }, .{}) });
            }
        }
    }

    // 2. Pins
    if (std.mem.containsAtLeast(u8, save_types, 1, "p")) {
        for (mepo.pin_groups, 0..) |pg, pg_i| {
            for (pg.items) |pin| {
                // Pin add
                var args_pinadd = std.StringArrayHashMap(std.json.Value).init(arena.allocator());
                try args_pinadd.put("handle", .{ .string = handle: {
                    if (pin.handle) |h| break :handle h;
                    break :handle "";
                } });
                try args_pinadd.put("group", .{ .integer = @intCast(pg_i) });
                try args_pinadd.put("lat", .{ .float = pin.lat });
                try args_pinadd.put("lon", .{ .float = pin.lon });
                try args_pinadd.put("is_structural", .{ .integer = b: {
                    if (pin.category == .Structural) break :b 1;
                    break :b 0;
                } });
                try statements.append(.{ .cmd = "pin_add", .args = try std.json.ArrayHashMap(std.json.Value).jsonParseFromValue(arena.allocator(), .{ .object = args_pinadd }, .{}) });

                // Pin metadata
                var it = pin.metadata.iterator();
                while (it.next()) |kv| {
                    var args_pinmeta = std.StringArrayHashMap(std.json.Value).init(arena.allocator());
                    try args_pinmeta.put("handle", .{ .string = handle: {
                        if (pin.handle) |h| break :handle h;
                        break :handle "";
                    } });
                    try args_pinmeta.put("group", .{ .integer = @intCast(pg_i) });
                    try args_pinmeta.put("key", .{ .string = kv.key_ptr.* });
                    try args_pinmeta.put("value", .{ .string = kv.value_ptr.* });
                    try statements.append(.{ .cmd = "pin_meta", .args = try std.json.ArrayHashMap(std.json.Value).jsonParseFromValue(arena.allocator(), .{ .object = args_pinmeta }, .{}) });
                }
            }
        }

        // Pin Group activate
        var args_pingroupactivate = std.StringArrayHashMap(std.json.Value).init(arena.allocator());
        try args_pingroupactivate.put("group", .{ .integer = mepo.pin_group_active });
        try statements.append(.{ .cmd = "pin_groupactivate", .args = try std.json.ArrayHashMap(std.json.Value).jsonParseFromValue(arena.allocator(), .{ .object = args_pingroupactivate }, .{}) });
    }

    const str = try std.json.stringifyAlloc(arena.allocator(), statements.items, .{
        .whitespace = .indent_2,
    });
    try jsonapi_file.writeAll(str);
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");

pub fn f_shellpipe(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const cmd = args[0].Text;
    try shellpipe(mepo, cmd);
}

pub fn shellpipe(mepo: *Mepo, cmd: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    var env_vars = std.BufMap.init(&arena.allocator);
    var v = try std.process.getEnvMap(&arena.allocator);

    try v.put("MEPO_WIN_W", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.w}));
    try v.put("MEPO_WIN_H", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.h}));

    try v.put("MEPO_C_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.lat}));
    try v.put("MEPO_C_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.lon}));

    try v.put("MEPO_TL_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{
      conversionutil.px_y_to_lat(mepo.get_y() - @divTrunc(@intCast(i32, mepo.h), @intCast(i32, 2)), mepo.zoom)
    }));
    try v.put("MEPO_TL_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{
      conversionutil.px_x_to_lon(mepo.get_x() - @divTrunc(@intCast(i32, mepo.w), @intCast(i32, 2)), mepo.zoom)
    }));

    try v.put("MEPO_BR_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{
      conversionutil.px_y_to_lat(mepo.get_y() + @divTrunc(@intCast(i32, mepo.h), @intCast(i32, 2)), mepo.zoom)
    }));
    try v.put("MEPO_BR_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{
      conversionutil.px_x_to_lon(mepo.get_x() + @divTrunc(@intCast(i32, mepo.w), @intCast(i32, 2)), mepo.zoom)
    }));

    const args = [_][]const u8 { "sh", "-c", cmd };
    var r = try std.ChildProcess.exec(.{
      .allocator = &arena.allocator, 
      .argv = args[0..],
      .env_map = &v
    });

    try mepo.mepolang_execute(r.stdout);
}

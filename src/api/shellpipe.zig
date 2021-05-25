const Fmap = @import("../Fmap.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");

pub fn f_shellpipe(fmap: *Fmap, args: [5]types.MepoArg) !void {
    const cmd = args[0].Text;
    try shellpipe(fmap, cmd);
}

pub fn shellpipe(fmap: *Fmap, cmd: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    var env_vars = std.BufMap.init(&arena.allocator);
    var v = try std.process.getEnvMap(&arena.allocator);

    // TODO: maybe as stdin?
    try v.set("MEPO_C_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{conversionutil.px_to_lat(fmap.y, fmap.zoom)}));
    try v.set("MEPO_C_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{conversionutil.px_to_lat(fmap.x, fmap.zoom)}));

    try v.set("MEPO_TL_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{
      conversionutil.px_to_lat(fmap.y - @divTrunc(@intCast(i32, fmap.h), @intCast(i32, 2)), fmap.zoom)
    }));
    try v.set("MEPO_TL_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{
      conversionutil.px_to_lon(fmap.x - @divTrunc(@intCast(i32, fmap.w), @intCast(i32, 2)), fmap.zoom)
    }));

    try v.set("MEPO_BR_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{
      conversionutil.px_to_lat(fmap.y + @divTrunc(@intCast(i32, fmap.h), @intCast(i32, 2)), fmap.zoom)
    }));
    try v.set("MEPO_BR_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{
      conversionutil.px_to_lon(fmap.x + @divTrunc(@intCast(i32, fmap.w), @intCast(i32, 2)), fmap.zoom)
    }));

    const args = [_][]const u8 { "sh", "-c", cmd };
    var r = try std.ChildProcess.exec(.{
      .allocator = &arena.allocator, 
      .argv = args[0..],
      .env_map = &v
    });

    try fmap.mepolang_execute(r.stdout);
}

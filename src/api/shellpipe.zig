const Fmap = @import("../Fmap.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_shellpipe(fmap: *Fmap, args: [5]types.MepoArg) !void {
    const cmd = args[0].Text;
    try shellpipe(fmap, cmd);
}

pub fn shellpipe(fmap: *Fmap, cmd: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const args = [_][]const u8 { "sh", "-c", cmd };
    var r = try std.ChildProcess.exec(.{
      .allocator = &arena.allocator, 
      .argv = args[0..],
    });

    try fmap.mepolang_execute(r.stdout);
}

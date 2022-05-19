const std = @import("std");
const p = @import("./utilprefs.zig");

pub fn log(comptime msg: []const u8, args: anytype) void {
    if (p.get(p.pref.debug_stderr).b) std.debug.print(msg, args);
}

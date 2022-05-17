const std = @import("std");
const utilprefs = @import("./utilprefs.zig");

pub fn log(comptime msg: []const u8, args: anytype) void {
    if (utilprefs.get("debug_stderr").b) std.debug.print(msg, args);
}

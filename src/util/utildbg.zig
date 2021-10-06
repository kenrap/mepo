const std = @import("std");

pub fn log(comptime msg: []const u8, args: anytype) void {
    std.debug.warn(msg, args);
}

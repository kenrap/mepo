const std = @import("std");

pub var debug_stderr: bool = true;

pub fn log(comptime msg: []const u8, args: anytype) void {
    if (debug_stderr) std.debug.print(msg, args);
}

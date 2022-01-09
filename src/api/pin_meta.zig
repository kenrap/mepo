const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");

pub fn f_pin_meta(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const handle = args[0].Text;
    const key = args[1].Text;
    const value = args[2].Text;
    try pin_meta(mepo, handle, key, value);
}

pub fn pin_meta(mepo: *Mepo, handle: []const u8, key: []const u8, value: []const u8) !void {
    if (value.len == 0) {
        // Delete pin meta logic
    }
}

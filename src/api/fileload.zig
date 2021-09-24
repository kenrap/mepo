const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const fileutil = @import("../util/fileutil.zig");

pub fn f_fileload(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const filepath = args[0].Text;
    try fileload(mepo, filepath);
}

fn fileload(mepo: *Mepo, filepath: []const u8) !void {
    const expanded_path = try fileutil.wordexp_filepath(mepo.allocator, filepath);
    const mepolang_file = try std.fs.openFileAbsolute(expanded_path, .{ .read = true });
    defer mepolang_file.close();
    const code = try mepolang_file.readToEndAlloc(mepo.allocator, 99999);
    defer mepo.allocator.free(code);
    try mepo.mepolang_execute(code);
}

const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilfile = @import("../util/utilfile.zig");

pub const spec = .{
    .name = "fileload",
    .args = (&[_]types.MepoArgTag{.Text})[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const filepath = args[0].Text;
    try fileload(mepo, filepath);
}

fn fileload(mepo: *Mepo, filepath: []const u8) !void {
    const expanded_path = try utilfile.wordexp_filepath(mepo.allocator, filepath);
    defer mepo.allocator.free(expanded_path);
    const mepolang_file = try std.fs.openFileAbsolute(expanded_path, .{ .read = true });
    defer mepolang_file.close();
    const code = try mepolang_file.readToEndAlloc(mepo.allocator, 99999);
    defer mepo.allocator.free(code);
    try mepo.mepolang_execute(code);
}

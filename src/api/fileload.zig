const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilfile = @import("../util/utilfile.zig");

pub const spec = types.MepoFnSpec{
    .name = "fileload",
    .desc = "Load JSON API expressions from an arbitrary filesystem file.",
    .args = &.{
        .{ .tag = .Text, .name = "filepath", .desc = "Path to file to load" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const filepath = args[0].Text;
    try fileload(mepo, filepath);
}

fn fileload(mepo: *Mepo, filepath: []const u8) !void {
    const expanded_path = try utilfile.wordexp_filepath(mepo.allocator, mepo.environ, filepath);
    defer mepo.allocator.free(expanded_path);
    const jsonapi_file = try std.Io.Dir.openFileAbsolute(mepo.io, expanded_path, .{});
    defer jsonapi_file.close(mepo.io);
    var buffer: [4096]u8 = undefined;
    var reader = jsonapi_file.reader(mepo.io, &buffer);
    const code = try reader.interface.allocRemaining(mepo.allocator, .limited(99999));
    defer mepo.allocator.free(code);
    try mepo.jsonapi_execute(code);
}

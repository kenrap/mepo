const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilfile = @import("../util/utilfile.zig");

pub const spec = .{
    .name = "filedump",
    .desc = "Save the current state of all preferences to a file.",
    .args = (&[_]types.MepoFnSpecArg{
        .{ .tag = .Text, .name = "filepath", .desc = "Path to file to save state to" },
    })[0..],
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const filepath = args[0].Text;
    try filedump(mepo, filepath);
}

fn filedump(mepo: *Mepo, filepath: []const u8) !void {
    const expanded_path = try utilfile.wordexp_filepath(mepo.allocator, filepath);
    defer mepo.allocator.free(expanded_path);
    try utilfile.mkdirp_folder_basename(expanded_path);
    const mepolang_file = try std.fs.createFileAbsoluteZ(expanded_path, .{});
    defer mepolang_file.close();

    // Save tables:
    //   bind_button
    //   bind_gesture
    //   bind_click
    //   bind_key
    //   bind_signal
    // Save prefs:
    //   loop prefs
    //   TODO: rework for pin_groups prefs merge into prefs system
    // Save pins:
    //   loop pins
}

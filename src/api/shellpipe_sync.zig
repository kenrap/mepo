const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utilplatform = @import("../util/utilplatform.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");
const p = @import("../util/utilprefs.zig");
const sdl = @import("../sdlshim.zig");
const filedump = @import("./filedump.zig");

pub const spec = .{
    .name = "shellpipe_sync",
    .desc = "Run a system (shell) command synchronously and pipe; STDOUT returned from command will be executed back as a JSON API expressions.",
    .args = &.{
        .{ .tag = .Text, .name = "shellcode", .desc = "Shell statement to execute" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const cmd = args[0].Text;
    try shellpipe_sync(mepo, cmd);
}

fn shellpipe_sync(mepo: *Mepo, cmd: []const u8) !void {
    try filedump.filedump(mepo, "rp", "$XDG_CACHE_HOME/mepo/shellpipe_savestate.json");

    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    try mepo.update_debug_message(
        try std.fmt.allocPrint(arena.allocator(), "Shellpipe sync ({s}) in progress - run!", .{cmd}),
    );
    try mepo.blit();
    const env_vars = try get_env_vars(mepo, arena.allocator());
    const args = [_][]const u8{ "sh", "-c", cmd };
    const process_result = try std.process.Child.run(.{
        .allocator = arena.allocator(),
        .argv = args[0..],
        .env_map = &env_vars,
        .max_output_bytes = 10000 * 1024,
    });
    const exitcode = process_result.term.Exited;
    try mepo.update_debug_message(
        try std.fmt.allocPrint(arena.allocator(), "Shellpipe sync ({s}) completed - execute, {d}!", .{ cmd, process_result.stdout.len }),
    );
    try mepo.blit();
    if (exitcode == 0) {
        try mepo.jsonapi_execute(process_result.stdout);
        try mepo.update_debug_message(null);
    } else {
        utildbg.log("shellpipe error: exited with code {d}\n{s}", .{ exitcode, process_result.stderr });
        try mepo.update_debug_message(process_result.stderr);
    }
}

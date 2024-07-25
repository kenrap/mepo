const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const sdl = @import("../sdlshim.zig");
const filedump = @import("./filedump.zig");
const run_shellpipe = @import("shellpipe_async.zig").run_shellpipe;

pub const spec = .{
    .name = "shellpipe_sync",
    .desc = "Run a system (shell) command synchronously and pipe; STDOUT returned from command will be executed back as a JSON API expressions.",
    .args = &.{
        .{ .tag = .Text, .name = "shellcode", .desc = "Shell statement to execute" },
    },
    .execute = execute,
};

fn execute(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    try filedump.filedump(mepo, "rp", "$XDG_CACHE_HOME/mepo/shellpipe_savestate.json");
    const cmd = args[0].Text;
    var request = try mepo.allocator.create(Request);
    request.mepo = mepo;
    request.cmd = try mepo.allocator.dupeZ(u8, cmd);
    for (mepo.uibuttons.items[0..1]) |*button| {
        if (!button.only_visible_when_sync_shellpipe)
            unreachable;
        mepo.allocator.free(button.text);
        button.text = try std.fmt.allocPrintZ(mepo.allocator, "Cancel {s}", .{ cmd });
    }
    sdl.SDL_DetachThread(sdl.SDL_CreateThread(run_sync_shellpipe, "sync_shellpipe", request));
}

const Request = struct {
    mepo: *Mepo,
    cmd: []const u8,
};

fn run_sync_shellpipe(userdata: ?*anyopaque) callconv(.C) c_int {
    const request: *Request = @alignCast(@ptrCast(userdata.?));
    defer request.mepo.allocator.destroy(request);
    run_shellpipe(request.mepo, null, request.cmd) catch |err|
        utildbg.log("Error running sync shellpipe: {}\n", .{err});
    request.mepo.sync_shellpipe_pid = null;
    return 0;
}

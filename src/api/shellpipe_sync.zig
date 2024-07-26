const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");
const blitfns = @import("../blit/blit.zig");
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
        button.text = try std.fmt.allocPrintZ(mepo.allocator, "Cancel {s}", .{cmd});
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
    request.mepo.shellpipe_sync_pid = null;
    return 0;
}

/// Helper function for SDL event handler during sync shellpipe
/// for killing the spawn processes.
fn kill_sync_shellpipe(mepo: *Mepo) types.Pending {
    if (mepo.shellpipe_sync_pid) |pid| {
        if (std.posix.kill(-pid, std.posix.SIG.KILL)) |_|
            utildbg.log("Killing sync shellpipe process {}\n", .{pid})
        else |err|
            utildbg.log("Error killing sync shellpipe process {}: {}\n", .{ pid, err });
        // No need to wait for termination as run_shellpipe already handles HUP events.
        return .Redraw;
    } else return .None;
}

pub fn event_keyup(mepo: *Mepo, e: sdl.SDL_Event) types.Pending {
    return switch (e.key.keysym.sym) {
        // XXX: Make binding configurable?  Escape key also cancel Zenity.
        sdl.SDLK_ESCAPE => kill_sync_shellpipe(mepo),
        else => .None,
    };
}

pub fn event_mousebuttonup(mepo: *Mepo, _: sdl.SDL_Event) types.Pending {
    if (mepo.fingers.items.len > 1) return .None;
    const cursor = mepo.scaled_mouse_position();
    if (!mepo.within_touch_bounds(cursor.x, cursor.y)) return .None;
    mepo.drag = null;
    return if (blitfns.blit_uibuttons(mepo, cursor) catch null) |clicked_btn|
        if (clicked_btn.only_visible_when_sync_shellpipe)
            kill_sync_shellpipe(mepo)
        else
            .None
    else
        .None;
}

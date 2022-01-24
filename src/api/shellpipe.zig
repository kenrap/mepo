const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utildbg = @import("../util/utildbg.zig");
const utilsdl = @import("../util/utilsdl.zig");
const sdl = @import("../sdlshim.zig");

pub fn f_shellpipe(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const cmd = args[0].Text;
    try shellpipe(mepo, cmd);
}

fn shellpipe(mepo: *Mepo, cmd: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    defer {
        // Fix for: https://todo.sr.ht/~mil/mepo-tickets/13
        // Currently there's a wayland-specific (tested on sway) bug wherein
        // if shellpipe is triggered from a keydown event for some reason
        // it buffers keyrepeat events; so this is a temporary fix for the
        // time being to simply clear out all keydown events on shellpipe
        sdl.SDL_PumpEvents();
        sdl.SDL_FlushEvents(@enumToInt(sdl.SDL_EventType.SDL_KEYDOWN), @enumToInt(sdl.SDL_EventType.SDL_KEYDOWN));
        utilsdl.sdl_push_resize_event();
    }

    try mepo.update_debug_message(
        try std.fmt.allocPrint(&arena.allocator, "Shellpipe ({s}) in progress - run!", .{cmd}),
    );
    try mepo.blit();

    const env_vars = env_vars: {
        var v = try std.process.getEnvMap(&arena.allocator);
        const bbox = mepo.bounding_box();

        // TODO: maybe this should be in seperate/helper fn?
        var cursor_x: c_int = undefined;
        var cursor_y: c_int = undefined;
        _ = sdl.SDL_GetMouseState(&cursor_x, &cursor_y);
        const cursor_lat = utilconversion.px_y_to_lat(mepo.get_y() - @divTrunc(@intCast(i32, mepo.win_h), 2) + cursor_y, mepo.zoom);
        const cursor_lon = utilconversion.px_x_to_lon(mepo.get_x() - @divTrunc(@intCast(i32, mepo.win_w), 2) + cursor_x, mepo.zoom);

        // Window and zoom info
        try v.put("MEPO_WIN_W", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.win_w}));
        try v.put("MEPO_WIN_H", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.win_h}));
        try v.put("MEPO_ZOOM", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.zoom}));

        // Center and bbox
        try v.put("MEPO_CENTER_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.lat}));
        try v.put("MEPO_CENTER_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.lon}));
        try v.put("MEPO_TL_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{bbox.topleft_lat}));
        try v.put("MEPO_TL_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{bbox.topleft_lon}));
        try v.put("MEPO_BR_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{bbox.bottomright_lat}));
        try v.put("MEPO_BR_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{bbox.bottomright_lon}));

        // Cursor position
        try v.put("MEPO_CURSOR_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{cursor_lat}));
        try v.put("MEPO_CURSOR_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{cursor_lon}));

        break :env_vars v;
    };

    const args = [_][]const u8{ "sh", "-c", cmd };
    const process_result = try std.ChildProcess.exec(.{
        .allocator = &arena.allocator,
        .argv = args[0..],
        .env_map = &env_vars,
        .max_output_bytes = 10000 * 1024,
    });
    const exitcode = process_result.term.Exited;

    try mepo.update_debug_message(
        try std.fmt.allocPrint(&arena.allocator, "Shellpipe ({s}) completed - execute, {d}!", .{ cmd, process_result.stdout.len }),
    );
    try mepo.blit();

    if (exitcode == 0) {
        try mepo.mepolang_execute(process_result.stdout);
        try mepo.update_debug_message(null);
    } else {
        utildbg.log("shellpipe error: exited with code {d}\n{s}", .{ exitcode, process_result.stderr });
        try mepo.update_debug_message(process_result.stderr);
    }
}

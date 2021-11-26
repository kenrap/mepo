const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utilconversion = @import("../util/utilconversion.zig");
const utildbg = @import("../util/utildbg.zig");

pub fn f_shellpipe(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const cmd = args[0].Text;
    try shellpipe(mepo, cmd);
}

fn shellpipe(mepo: *Mepo, cmd: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    const env_vars = env_vars: {
        var v = try std.process.getEnvMap(&arena.allocator);
        const bbox = mepo.bounding_box();

        try v.put("MEPO_WIN_W", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.win_w}));
        try v.put("MEPO_WIN_H", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.win_h}));
        try v.put("MEPO_ZOOM", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.zoom}));
        try v.put("MEPO_C_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.lat}));
        try v.put("MEPO_C_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{mepo.lon}));
        try v.put("MEPO_TL_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{bbox.topleft_lat}));
        try v.put("MEPO_TL_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{bbox.topleft_lon}));
        try v.put("MEPO_BR_LAT", try std.fmt.allocPrint(&arena.allocator, "{d}", .{bbox.bottomright_lat}));
        try v.put("MEPO_BR_LON", try std.fmt.allocPrint(&arena.allocator, "{d}", .{bbox.bottomright_lon}));
        break :env_vars v;
    };

    const args = [_][]const u8{ "sh", "-c", cmd };
    const process_result = try std.ChildProcess.exec(.{ .allocator = &arena.allocator, .argv = args[0..], .env_map = &env_vars });
    const exitcode = process_result.term.Exited;

    if (exitcode == 0) {
        try mepo.mepolang_execute(process_result.stdout);
        try mepo.update_debug_message(null);
    } else {
        utildbg.log("shellpipe error: exited with code {d}\n{s}", .{ exitcode, process_result.stderr });
        try mepo.update_debug_message(process_result.stderr);
    }
}

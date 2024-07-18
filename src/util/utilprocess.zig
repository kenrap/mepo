const std = @import("std");
const utildbg = @import("../util/utildbg.zig");

// In the case that []const u8 is returned, it's the callers responsibility
// to free the return value
pub fn run_subprocess(
    allocator: std.mem.Allocator, 
    cmd: []const u8,
    env_vars: *const std.process.EnvMap, 
    _: ?*std.process.Child.Id,
    //set_process_id_ptr_opt: ?*std.process.Child.Id,
) !?[]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const args = [_][]const u8{ "sh", "-c", cmd };
    var child = std.process.Child.init(&args, arena.allocator());
    child.pgid = 0;
    child.allocator = arena.allocator();
    child.argv = args[0..];
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.env_map = env_vars;
    var stdout = std.ArrayList(u8).init(arena.allocator());
    var stderr = std.ArrayList(u8).init(arena.allocator());
    errdefer {
        stdout.deinit();
        stderr.deinit();
    }
    try child.spawn();
    //if (set_process_id_ptr_opt != null) {
    //    //set_process_id_ptr_opt.? = child.id;
    //}
    try child.collectOutput(&stdout, &stderr, 10000 * 1024);
    const term = try child.wait();
    switch (term) {
        .Exited => |exitcode| {
            if (exitcode == 0) {
                return try stdout.toOwnedSlice();
            }
        },
        else => {
            utildbg.log("Early termination of async_shellpipe (via signal, stopped, etc.)\n", .{});
        }
    }
    return null;
}

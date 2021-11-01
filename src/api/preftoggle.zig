const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const utildbg = @import("../util/utildbg.zig");

pub fn f_preftoggle(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const name = args[0].Text;

    if (std.mem.eql(u8, "help", name)) {
        mepo.help = !mepo.help;
    } else if (std.mem.eql(u8, "download_bar", name)) {
        mepo.download_bar = !mepo.download_bar;
    } else if (std.mem.eql(u8, "debug_vars", name)) {
        mepo.debug_vars = !mepo.debug_vars;
    } else if (std.mem.eql(u8, "debug_message_enabled", name)) {
        mepo.debug_message_enabled = !mepo.debug_message_enabled;
    } else if (std.mem.eql(u8, "debug_tiles", name)) {
        mepo.debug_tiles = !mepo.debug_tiles;
    } else if (std.mem.eql(u8, "debug_stderr", name)) {
        utildbg.debug_stderr = !utildbg.debug_stderr;
    } else if (std.mem.eql(u8, "crosshair_on", name)) {
        mepo.crosshair_on = !mepo.crosshair_on;
    }
}

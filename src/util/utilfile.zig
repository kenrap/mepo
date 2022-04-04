const std = @import("std");
const wordexp = @cImport({
    @cInclude("wordexp.h");
});
const cstdlib = @cImport({
    @cInclude("stdlib.h");
});


/// Runs underlying wordexp (see man 3 wordexp) to expand globs & handle tilde
/// expansion.
///
/// Caller responsible for freeing returned ptr memory
pub fn wordexp_filepath(allocator: std.mem.Allocator, path: []const u8) ![:0]const u8 {
    if (std.os.getenv("XDG_CONFIG_HOME") == null) {
        if (std.os.getenv("HOME")) |home| {
            const xdg_home = try std.fmt.allocPrintZ(allocator, "XDG_CONFIG_HOME={s}/.config", .{home});
            defer allocator.free(xdg_home);
            _ = cstdlib.putenv(xdg_home);
            // Note at this point std.os.getenv("XDG_CONFIG_HOME") works
            // but wordexp doesnt...?
        }
    }

    var expansion: wordexp.wordexp_t = undefined;
    defer wordexp.wordfree(&expansion);

    if (wordexp.wordexp(&path[0], &expansion, 0) != 0) {
        return error.CacheDirExpansionFail;
    } else {
        const expanded_path: [:0]u8 = try std.fmt.allocPrintZ(allocator, "{s}", .{expansion.we_wordv[0]});
        std.debug.print("Expanded to: {s}\n", .{expanded_path});
        return expanded_path;
    }
}

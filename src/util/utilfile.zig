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
            const xdg_home = try std.fmt.allocPrintZ(allocator, "{s}/.config", .{home});
            defer allocator.free(xdg_home);
            _ = cstdlib.setenv("XDG_CONFIG_HOME", xdg_home, 1);
        }
    }

    var expansion: wordexp.wordexp_t = undefined;
    defer wordexp.wordfree(&expansion);

    if (wordexp.wordexp(&path[0], &expansion, 0) != 0) {
        return error.CacheDirExpansionFail;
    } else {
        return try std.fmt.allocPrintZ(allocator, "{s}", .{expansion.we_wordv[0]});
    }
}

const std = @import("std");
const wordexp = @cImport({
    @cInclude("wordexp.h");
});

pub fn wordexp_filepath(allocator: *std.mem.Allocator, path: []const u8) ![:0]const u8 {
    var expansion: wordexp.wordexp_t = undefined;
    defer wordexp.wordfree(&expansion);

    if (wordexp.wordexp(&path[0], &expansion, 0) != 0) {
        return error.CacheDirExpansionFail;
    } else {
        const expanded_path: [:0]u8 = try std.fmt.allocPrintZ(allocator, "{s}", .{expansion.we_wordv[0]});
        return expanded_path;
    }
}

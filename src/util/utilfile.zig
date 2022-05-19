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

    // Within config, we assume user can pass XDG_{CONFIG,CACHE}_HOME to
    // fileload etc. and callers of this fn; so here we just follow XDG default
    // and provide default XDG dir if unset; e.g. if XDG_CONFIG_HOME unset
    // use ~/.config
    for (&[_]struct {
        env_var: [:0]const u8,
        default_home_path: [:0]const u8,
    }{
        .{
            .env_var = "XDG_CONFIG_HOME",
            .default_home_path = ".config",
        },
        .{
            .env_var = "XDG_CACHE_HOME",
            .default_home_path = ".cache",
        },
    }) |default_mapping| {
        if (std.os.getenv(default_mapping.env_var) != null) continue;
        if (std.os.getenv("HOME")) |home_dir| {
            const value = try std.fmt.allocPrintZ(allocator, "{s}/{s}", .{ home_dir, default_mapping.default_home_path });
            defer allocator.free(value);
            _ = cstdlib.setenv(default_mapping.env_var, value, 1);
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


pub fn mkdirp_folder_basename(file_path: []const u8) !void {
    if (std.fs.path.dirname(file_path)) |dir_fp| {
        try std.fs.cwd().makePath(dir_fp);
        return;
    }
    return error.DirnameFail;
}

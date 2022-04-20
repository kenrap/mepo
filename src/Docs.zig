const std = @import("std");
const FnTable = @import("./api/_FnTable.zig");

pub fn generate() !void {
    const Format = enum { Markdown, Manpage };
    const use_format : Format = .Markdown;

    switch (use_format) {
        .Markdown => {
            std.debug.print("# Mepolang API\n", .{});
            for (FnTable.fn_specs) |fnc| {
                std.debug.print("## {s}\n", .{fnc.name});
                std.debug.print("\n", .{});
            }
        },
        .Manpage => {
            std.debug.print("Manpage format unsupported for now\n", .{});
        }
    }
}

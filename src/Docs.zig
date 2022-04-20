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
                std.debug.print("{s}\n\n", .{fnc.desc});
                if (fnc.args.len > 0) {
                    std.debug.print("**Arguments**:\n", .{});
                    for (fnc.args) |arg| {
                        const tag = if (arg.tag == .Number) "(number)" else "(text) ";
                        std.debug.print("  - {s} {s}: {s}\n", .{arg.name, tag, arg.desc});
                    }
                }
                std.debug.print("\n", .{});
            }
        },
        .Manpage => {
            std.debug.print("Manpage format unsupported for now\n", .{});
        }
    }
}

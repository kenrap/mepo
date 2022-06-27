const std = @import("std");
const FnTable = @import("./api/_FnTable.zig");
const config = @import("./config.zig");

pub fn generate() !void {
    const Format = enum { Markdown, Manpage };
    const use_format: Format = .Markdown;
    const stdout = std.io.getStdOut().writer();

    switch (use_format) {
        .Markdown => {
            try stdout.print("# Mepolang API ({s})\n", .{config.Version});
            for (FnTable.fn_specs) |fnc| {
                try stdout.print("## **{s}**\n", .{fnc.name});
                try stdout.print("{s}\n\n", .{fnc.desc});
                if (fnc.args.len > 0) {
                    try stdout.print("**Arguments**:\n\n", .{});
                    try stdout.print("| **Name** | **Datatype** | **Description** |\n", .{});
                    try stdout.print("| -------- | ------------ | --------------- |\n", .{});
                    for (fnc.args) |arg| {
                        const tag = if (arg.tag == .Number) "Number" else "Text  ";
                        try stdout.print("| {s} | {s} | {s} |\n", .{ arg.name, tag, arg.desc });
                    }
                }
                try stdout.print("\n", .{});
            }
        },
        .Manpage => {
            std.debug.print("Manpage format unsupported for now\n", .{});
        },
    }
}

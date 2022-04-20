const std = @import("std");
const FnTable = @import("./api/_FnTable.zig");

pub fn generate() !void {
    const Format = enum { Markdown, Manpage };
    const use_format : Format = .Markdown;
    const stdout = std.io.getStdOut().writer();

    switch (use_format) {
        .Markdown => {
            try stdout.print("# Mepolang API\n", .{});
            for (FnTable.fn_specs) |fnc| {
                try stdout.print("## {s}\n", .{fnc.name});
                try stdout.print("{s}\n\n", .{fnc.desc});
                if (fnc.args.len > 0) {
                    try stdout.print("**Arguments**:\n", .{});
                    for (fnc.args) |arg| {
                        const tag = if (arg.tag == .Number) "(number)" else "(text) ";
                        try stdout.print("  - {s} {s}: {s}\n", .{arg.name, tag, arg.desc});
                    }
                }
                try stdout.print("\n", .{});
            }
        },
        .Manpage => {
            try stdout.print("Manpage format unsupported for now\n", .{});
        }
    }
}

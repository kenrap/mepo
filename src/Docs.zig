const std = @import("std");
const FnTable = @import("./api/_FnTable.zig");
const config = @import("./config.zig");
const utilprefs = @import("./util/utilprefs.zig");

pub const CliFlags = &[_]struct{
    flag: []const u8,
    param: ?[]const u8 = null,
    desc: []const u8,
}{
    .{ .flag = "-docmdapi", .desc = "Print markdown documentation for mepolang API to STDOUT" },
    .{ .flag = "-docmdprefs", .desc = "Print markdown documentation for prefs to STDOUT" },
    .{ .flag = "-docman", .desc = "Print manpage documentation for mepolang API to STDOUT" },
    .{ .flag = "-i", .desc = "Read mepolang from STDIN continually" },
    .{ .flag = "-e", .desc = "Enable debug mode to log messages to STDERR" },
    .{ .flag = "-ndc", .desc = "Disable default config, e.g. not wanting defaults bindings etc.. like `cat my_config | mepo -ndc`" },
    .{ .flag = "-sw", .desc = "Use software renderer rather then default GPU/hardware based renderer" },
    .{ .flag = "-v", .desc = "Print version number" },
    .{ .flag = "-h", .desc = "Print this help text" },
    .{ .flag = "-d", .desc = "Non-interactively download tiles for given range", .param = "lat_a,lon_a,lat_b,lon_b,zoom_min,zoom_max" },
};

const PrefsIntro = 
  \\Internally mepo keeps track of a number of preferences which control all
  \\state for the application. These preferences can all be set with the commands
  \\`preset_n` for numerical prerefences and `prefset_t` for textual preferences.
  \\You can also use `filedump` to examine the current values of all preferences.
  ;

pub fn generate(allocator: std.mem.Allocator, format: enum{MarkdownAPI, MarkdownPrefs, Manpage}) !void {
    const stdout = std.io.getStdOut().writer();

    switch (format) {
        .MarkdownAPI => {
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
                try stdout.print("\n---\n\n", .{});
            }
        },
        .MarkdownPrefs => {
            try stdout.print("# Mepolang Preferences ({s})\n\n{s}\n\n", .{config.Version, PrefsIntro});
            
            try stdout.print(
                \\| **Name** | **Description** | **Datatype** | **Min** | **Max** | **Default Value** |
                \\| -------- | --------------- | ------------ | ------- | ------- | ----------------- |
                \\
                , 
                .{}
            );
            for (utilprefs.prefs_mapping) |pref| {
                const datatype = switch(pref.value) {
                    .b =>    "Bool (0/1)",
                    .t =>    "Text      ",
                    .f =>    "Float     ",
                    .u =>    "Uint8     ",
                    .u24 =>  "Uint24    ",
                };

                var min : []const u8 = "";
                var max : []const u8 = "";

                if (pref.bounds) |bounds| {
                    min = try std.fmt.allocPrint(allocator, "{d}", .{bounds.min});
                    max = try std.fmt.allocPrint(allocator, "{d}", .{bounds.max});
                    defer allocator.free(min);
                    defer allocator.free(max);
                }

                var value : []const u8 = "";
                switch(pref.value) {
                    .t =>    { value = try std.fmt.allocPrint(allocator, "{s}", .{pref.value.t}); },
                    .b =>    { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.b}); },
                    .f =>    { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.f}); },
                    .u =>    { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.u}); },
                    .u24 =>  { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.u24}); },
                }
                defer allocator.free(value);

                try stdout.print(
                    "| {s} | {s} | {s} | {s} | {s} | {s} |\n",
                    .{
                        pref.name,
                        pref.desc,
                        datatype,
                        min,
                        max,
                        value
                    }
                );
            }
        },
        .Manpage => {
            try stdout.print(
              \\.TH Mepo 1
              \\
              \\.SH NAME
              \\mepo - fast, simple, and hackable OSM map viewer for desktop & mobile Linux
              \\
              \\.SH SYNOPSIS
              \\.B mepo
              \\[\fB\-i\fR]
              ,
              .{},
            );
            for (CliFlags) |flag_spec| {
                if (flag_spec.param) |param| {
                    try stdout.print("[\\fB\\{s}\\fR \\fI{s}\\fR]", .{flag_spec.flag, param},
                    );
                } else {
                    try stdout.print("[\\fB\\{s}]", .{flag_spec.flag});
                }
            }
            try stdout.print(
                \\
                \\.SH DESCRIPTION
                \\.B Mepo
                \\is a fast, simple, and hackable OSM map viewer for desktop & mobile
                \\Linux devices (like the PinePhone, Librem 5, pmOS devices etc.) and both
                \\environment's various user interfaces (Wayland & X inclusive). Mepo
                \\works both offline and online, features a minimalist both touch/mouse
                \\and keyboard compatible interface, and offers a UNIX-philosophy
                \\inspired underlying design, exposing a powerful command language called
                \\[Mepolang](doc/userguide.md#strongmepolangstrong) capable of being
                \\scripted to provide things like custom bounding-box search scripts,
                \\bookmarks, and more.
                \\
                \\.SH OPTIONS
                \\
                ,
                .{}
            );
            for (CliFlags) |flag_spec| {
                if (flag_spec.param) |param| {
                    try stdout.print(
                        \\.TP
                        \\.BR \{s} ", " \{s}\ {s}\fR
                        \\{s}
                        \\
                        , 
                        .{flag_spec.flag, flag_spec.flag, param, flag_spec.desc},
                    );
                } else {
                    try stdout.print(
                        \\.TP
                        \\.BR \{s} \fR
                        \\{s}
                        \\
                        ,
                        .{flag_spec.flag, flag_spec.desc},
                    );
                }
            }

            try stdout.print(".SH MEPOLANG\n", .{});
            for (FnTable.fn_specs) |fnc| {
                try stdout.print(".B {s}\n", .{fnc.name});
                try stdout.print("{s}\n\nArguments:\n", .{fnc.desc});
                for (fnc.args) |arg| {
                    const tag = if (arg.tag == .Number) "Number" else "Text  ";
                    try stdout.print("  {s} ({s}): {s}\n", .{ arg.name, tag, arg.desc });
                }
                try stdout.print("\n", .{});
            }

            try stdout.print(".SH PREFERENCES\n", .{});
            try stdout.print("{s}\n", .{PrefsIntro});
            for (utilprefs.prefs_mapping) |pref| {
                const datatype = switch(pref.value) {
                    .b =>    "Bool (0/1)",
                    .t =>    "Text      ",
                    .f =>    "Float     ",
                    .u =>    "Uint8     ",
                    .u24 =>  "Uint24    ",
                };

                var min : []const u8 = "";
                var max : []const u8 = "";

                if (pref.bounds) |bounds| {
                    min = try std.fmt.allocPrint(allocator, "{d}", .{bounds.min});
                    max = try std.fmt.allocPrint(allocator, "{d}", .{bounds.max});
                    defer allocator.free(min);
                    defer allocator.free(max);
                }

                var value : []const u8 = "";
                switch(pref.value) {
                    .t =>    { value = try std.fmt.allocPrint(allocator, "{s}", .{pref.value.t}); },
                    .b =>    { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.b}); },
                    .f =>    { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.f}); },
                    .u =>    { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.u}); },
                    .u24 =>  { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.u24}); },
                }
                defer allocator.free(value);

                try stdout.print(
                    \\.B {s} ({s})
                    \\ Default: {s} / Min: {s} / Max: {s}
                    \\ {s}
                    \\
                    \\
                    ,
                    .{
                        pref.name,
                        datatype,
                        value,
                        min,
                        max,
                        pref.desc,
                    }
                );
            }



            try stdout.print(
                \\
                \\.SH VERSION
                \\Manual page generated against mepo version {s}
                \\
                \\.SH AUTHORS
                \\Mepo is written by Miles Alan <m@milesalan.com>. Full list 
                \\of contributors can be seen in git shortlog
                \\
                \\.SH SEE ALSO
                \\TODO
                \\
                \\.SH CONTRIBUTING
                \\Bugs and feature dicussions can be sent to ~mil/mepo-devel@lists.sr.ht
                ,
                .{config.Version}
            );
        },
    }
}

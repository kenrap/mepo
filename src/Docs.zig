const std = @import("std");
const FnTable = @import("./api/_FnTable.zig");
const config = @import("./config.zig");
const utilprefs = @import("./util/utilprefs.zig");

pub const CliFlags = &[_]struct{
    flag: []const u8,
    param: ?[]const u8 = null,
    desc: []const u8,
}{
    .{ .flag = "-docmd", .desc = "Print markdown documentation for Mepolang to STDOUT" },
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
    \\
    \\Below is an exhaustive list of all available preferences:
    \\
  ;

const MepolangIntro =
    \\Mepolang is Mepo's command language API for IPC that can be sent to its
    \\process via STDIN continually. Through this mechanism you can control
    \\Mepo: using an external script, by simply piping in a configuration
    \\on boot, or by using a FIFO (eventually). Upon the 1.0 release it is
    \\planned that there will be two commands included to run Mepo: `mepo`
    \\and `mepo_run.sh` wherein `mepo_run.sh` will just be a script that runs
    \\`cat default_config | mepo`.
    \\
    \\Many of Mepo's commands play nice together. A good place to look to
    \\understand Mepolang's utilization is the [default config](../src/config.zig). For
    \\example `bind_key` actually also takes Mepolang text to run as an
    \\argument. Similarly the result of `shellpipe`, runs Mepolang text given
    \\the STDOUT result of a (user) [shellscript](../scripts).
    ;

const MepolangSyntax = 
    \\**Syntax rules are as follows:**
    \\
    \\- Each statement is made up of multiple tokens.
    \\- Each Mepolang command should be terminated by a semicolon.
    \\- The first token in a statement is always the command name.
    \\- Tokens should be separated by whitespace.
    \\- Each token is either:
    \\  - Text
    \\    - Just plain text, by default assumed to be a single word.
    \\    - If you want to use a space within an argument use `[ square brackets ]` to create a multiword token.
    \\    - If you want to have a text token that looks like a number, use square brackets like `[-3]`
    \\  - Number
    \\    - A floating point number, either decimal (e.g. `3.77`) or whole (e.g. `3`).
    \\    - Can be negative like `-22.22` or positive like `22.22`
    \\
    \\
    \\**Example mepolang text:**
    \\
    \\```sh
    \\commandname textarg [multi word arg] 2;
    \\commandname2 arg 8.373 anothertextarg;
    \\```
    \\
    ;


pub fn generate(allocator: std.mem.Allocator, format: enum{Markdown, Manpage}) !void {
    const stdout = std.io.getStdOut().writer();

    switch (format) {
        .Markdown => {
            try stdout.print(
                \\# Mepolang
                \\
                \\<div class='toc'>
                \\<ul>
                \\<li><a href="#overview">Overview</a></li>
                \\<li><a href="#syntax">Syntax</a></li>
                \\<li>
                \\  <a href="#api">API</a>
                \\  <ul>
                ,
                .{},
            );
            for (FnTable.fn_specs) |fnc| {
                try stdout.print("<li><a href='#{s}'>{s}</a></li>\n", .{fnc.name, fnc.name});
            }
            try stdout.print(
                \\</ul>
                \\</li>
                \\<li><a href="#preferences">Preferences</a></li>
                \\</ul>
                \\</div>
                \\
                \\## Overview
                \\{s}
                \\
                \\## Syntax
                \\{s}
                \\
                \\## API
                \\
                ,
                .{MepolangIntro, MepolangSyntax}
            );

            // API Section
            for (FnTable.fn_specs) |fnc| {
                try stdout.print("### **{s}**\n", .{fnc.name});
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


            // Prefs Section
            try stdout.print(
                \\## Preferences
                \\
                \\ {s}
                \\
                ,
                .{ PrefsIntro },
            );
            try stdout.print(
                \\| **Name** | **Description** | **Datatype** | **Min** | **Max** | **Default Value** |
                \\| -------- | --------------- | ------------ | ------- | ------- | ----------------- |
                \\
                , 
                .{}
            );
            for (utilprefs.prefs_mapping) |pref| {
                const datatype = switch(pref.value) {
                    .b =>    "Number (bool)",
                    .t =>    "Text",
                    .f =>    "Number (float)",
                    .u =>    "Number (u8)",
                    .u24 =>  "Number (u24)",
                };

                var value : []const u8 = "";
                switch(pref.value) {
                    .t =>    { value = try std.fmt.allocPrint(allocator, "{s}", .{pref.value.t}); },
                    .b =>    { 
                        if (pref.value.b) {
                            value = try std.fmt.allocPrint(allocator, "{d}", .{1});
                        } else {
                            value = try std.fmt.allocPrint(allocator, "{d}", .{0});
                        }
                    },
                    .f =>    { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.f}); },
                    .u =>    { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.u}); },
                    .u24 =>  { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.u24}); },
                }
                defer allocator.free(value);


                if (pref.bounds) |bounds| {
                    try stdout.print(
                        "| {s} | {s} | {s} | {d} | {d} | {s} |\n",
                        .{ pref.name, pref.desc, datatype, bounds.min, bounds.max, value }
                    );
                } else {
                    try stdout.print(
                        "| {s} | {s} | {s} |  |  | {s} |\n",
                        .{ pref.name, pref.desc, datatype, value }
                    );
                }

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
                try stdout.print(
                    \\.PP
                    \\.B {s}
                    \\.br
                    \\{s}
                    \\
                    ,
                    .{fnc.name, fnc.desc}
                );
                if (fnc.args.len > 0) {
                    try stdout.print(".br\n.br\nArguments:\n", .{});
                    for (fnc.args) |arg| {
                        const tag = if (arg.tag == .Number) "Number" else "Text";
                        try stdout.print("  {s} ({s}): {s}\n", .{ arg.name, tag, arg.desc });
                    }
                }
                try stdout.print("\n", .{});
            }

            try stdout.print(".SH PREFERENCES\n", .{});
            try stdout.print("{s}\n", .{PrefsIntro});
            for (utilprefs.prefs_mapping) |pref| {
                const datatype = switch(pref.value) {
                    .b =>    "Number (bool)",
                    .t =>    "Text",
                    .f =>    "Number (float)",
                    .u =>    "Number (u8)",
                    .u24 =>  "Number (u24)",
                };

                var value : []const u8 = "";
                
                switch(pref.value) {
                    .t =>    { value = try std.fmt.allocPrint(allocator, "{s}", .{pref.value.t}); },
                    .b =>    { 
                        if (pref.value.b) {
                            value = try std.fmt.allocPrint(allocator, "{d}", .{1});
                        } else {
                            value = try std.fmt.allocPrint(allocator, "{d}", .{0});
                        }
                    },
                    .f =>    { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.f}); },
                    .u =>    { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.u}); },
                    .u24 =>  { value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.u24}); },
                }
                defer allocator.free(value);

                if (pref.bounds) |bounds| {
                    try stdout.print(
                        \\.PP
                        \\.B {s}
                        \\.br
                        \\Datatype: {s}
                        \\.br
                        \\Default: {s} / Min: {d} / Max: {d}
                        \\.br
                        \\{s}
                        \\
                        \\
                        ,
                        .{ pref.name, datatype, value, bounds.min, bounds.max, pref.desc }
                    );
                } else {
                    try stdout.print(
                        \\.PP
                        \\.B {s}
                        \\.br
                        \\Datatype: {s}
                        \\.br
                        \\Default: {s}
                        \\.br
                        \\{s}
                        \\
                        \\
                        ,
                        .{ pref.name, datatype, value, pref.desc }
                    );

                }


            }

            try stdout.print(
                \\
                \\.SH VERSION
                \\Manual page has been generated against mepo version {s}
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

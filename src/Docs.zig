const std = @import("std");
const FnTable = @import("./api/_FnTable.zig");
const config = @import("./config.zig");
const utilprefs = @import("./util/utilprefs.zig");

pub const CliFlags = &[_]struct{
    flag: []const u8,
    param: ?[]const u8 = null,
    desc: []const u8,
}{
    .{ .flag = "-docmd", .desc = "Print markdown documentation for the mepolang API to STDOUT." },
    .{ .flag = "-docman", .desc = "Print manpage documentation for the mepolang API to STDOUT.  Can be viewed with man via: `mepo -docman | man -l`." },
    .{ .flag = "-i", .desc = "Read mepolang from STDIN continually. Can be used for interactive debugging or scripting via: `tee | mepo -i` or `./myscript | mepo -i`." },
    .{ .flag = "-e", .desc = "Enable debug mode to log messages to STDERR." },
    .{ .flag = "-ndc", .desc = "Disable default/base config, this is useful if you have a custom config and don't wish to use the default bindings, etc.. for example: `cat my_config | mepo -ndc -i`." },
    .{ .flag = "-sw", .desc = "Use software renderer rather then default GPU/hardware based renderer." },
    .{ .flag = "-v", .desc = "Print version number." },
    .{ .flag = "-h", .desc = "Print this help text." },
    .{ .flag = "-d", .desc = "Non-interactively download tiles for given range.", .param = "lat_a,lon_a,lat_b,lon_b,zoom_min,zoom_max" },
};

const PrefsIntro = 
    \\Internally mepo keeps track of a number of preferences which control all
    \\state for the application. These preferences can be set with the commands
    \\`preset_n` for numerical preferences and `prefset_t` for textual preferences.
    \\You can also use `filedump` to examine the current values of all preferences.
    \\
    \\Below is an exhaustive list of all available preferences:
    \\
  ;

const MepolangIntro =
    \\Mepolang is mepo's comand language for runtime IPC and configuration. It
    \\takes the form of a plain-text DSL (domain-specific-language) with a
    \\number of [commands](#api). Mepolang makes configuration, customizing,
    \\and hacking on mepo simple. To test mepolang simply, you may run mepo
    \\with the `-i` argument which reads mepolang from STDIN. The most basic
    \\example might look like:
    \\
    \\```sh
    \\# Set the crosshair size to 200
    \\echo "prefset_n crosshair_size 200;" | mepo -i
    \\
    \\# Or load a custom mepolang file from the filesystem
    \\echo "fileload /home/foo/my_mepolang_file;" | mepo -i
    \\```
    \\
    \\Within the filesystem, based on the [default
    \\base configuration](#base-configuration), the paths
    \\`$XDG_CONFIG_HOME/mepo/config` and `$XDG_CONFIG_HOME/mepo/bookmarks`
    \\are automatically loaded on boot; as such, for most end users, 
    \\configuration simply may be placed in `~/.config/mepo/config`.
    \\
    \\The rest of this document describes the [syntax rules](#syntax),
    \\[API commands](#api), and [preferences](#preferences) of mepolang.
    \\Note also that mepo by default runs with certain mepolang
    \\statement's applied by default, this is known as the [base
    \\configuration](#base-configuration).  Advanced details on scripting
    \\and detailed practical examples of using mepolang may be viewed in
    \\the [scripting guide](/scriptingguide.html) which should be seen as
    \\a supplement to this document.
    ;

const MepolangSyntax = 
    \\Syntax rules are as follows:
    \\
    \\- Mepolang syntax is composed of statements.
    \\- Each statement is made up of multiple tokens and terminated by a semicolon.
    \\- Tokens are separated by whitespace.
    \\- The first token in a statement is always the command name.
    \\- Each token is either:
    \\  - **Text:** Just plain text, by default assumed to be a single word.
    \\    If you want to use a space within a token use `[ square brackets ]`
    \\    to create a multiword token. If you want to have a text token that
    \\    looks like a number, use square brackets like `[-3]`.
    \\  - **Number:** A floating point number, either decimal (e.g. `3.77`)
    \\    or whole (e.g. `3`). Can be negative like `-22.22` or positive
    \\    like `22.22`.
    \\
    \\
    \\Example mepolang text:
    \\
    \\```sh
    \\commandname textarg [multi word arg] 2;
    \\commandname2 arg 8.373 anothertextarg;
    \\```
    \\
    ;

const DocEnvVarsShellpipe = 
    \\Both `shellpipe_sync` and `shellpipe_async` expose a number of ENV
    \\variables to the target script called. See below for the accessible
    \\ENV variables exposed.
    \\
    \\- `MEPO_WIN_W`: Width of the UI window
    \\- `MEPO_WIN_H`: Height of the UI window
    \\- `MEPO_ZOOM`: Curent zoom level
    \\- `MEPO_CENTER_LAT`: Latitude of the center point of the screen
    \\- `MEPO_CENTER_LON`: Longitude of the center point of the screen
    \\- `MEPO_TL_LAT`: Latitude of the top left point on the screen
    \\- `MEPO_TL_LON`: Longitude of the top left point on the screen
    \\- `MEPO_BR_LAT`: Latitude of the bottom right point on the screen
    \\- `MEPO_BR_LON`: Longitude of the bottom right point on the screen
    \\- `MEPO_CURSOR_LAT`: Latitude of the cursor position
    \\- `MEPO_CURSOR_LON`: Lontitude of the cursor position
    ;

const DocBaseConfigIntro =
    \\The following base configuration was built into Mepo as of
    \\the current release version. Note, preferences can
    \\be overriden directly for example with `prefset_n` and
    \\`prefset_t`. While there are not unbinding commands currently
    \\supported, you can forgo the default configuration by using
    \\the `-ndc` commandline flag.
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
                \\<li><a href="#version">Version</a></li>
                \\<li><a href="#api">API</a></li>
                \\<li><a href="#preferences">Preferences</a></li>
                \\<li><a href="#shellpipe-env-variables">Shellpipe ENV Variables</a></li>
                \\<li><a href="#base-configuration">Base Configuration</a></li>
                \\</ul>
                \\</div>
                \\
                \\## Overview
                \\{s}
                \\
                \\---
                \\
                \\## Syntax
                \\{s}
                \\
                \\---
                \\
                \\## Version
                \\This document was compiled against mepo version: **{s}**.
                \\
                \\The following sections for [API](#api),
                \\[preferences](#preferences), [shellpipe
                \\env variables](#shellpipe-env-variables), and [base
                \\configuration](#base-configuration) are dependent on / assume
                \\the above version of mepo this document was compiled against,
                \\you may check your version of mepo with `mepo -v`.
                \\
                \\---
                \\
                \\## API
                \\
                ,
                .{MepolangIntro, MepolangSyntax, config.Version}
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

            try stdout.print(
                \\
                \\---
                \\
                \\## Shellpipe ENV Variables
                \\
                \\{s}
                \\
                \\---
                \\
                \\## Base Configuration
                \\
                \\{s}
                \\
                \\```sh
                \\{s}
                \\```
                ,
                .{DocEnvVarsShellpipe, DocBaseConfigIntro, config.DefaultBaseConfig},
            );
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
                \\mepolang capable of being scripted to provide things like custom
                \\bounding-box search scripts, bookmarks, and more.
                \\
                \\This document describes usage of mepo, commandline flags,
                \\usage of mepolang (mepo's configuration and IPC language),
                \\and the default configuration. For more in-depth documentation
                \\covering UI usage, guides, scripting, and demo videos
                \\visit mepo's documentation website at http://mepo.milesalan.com
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

            try stdout.print(
                \\
                \\.SH FILES
                \\
                \\The directory
                \\.B
                \\$XDG_CACHE_HOME/mepo
                \\is used to store tiledata
                \\and savestate. If $XDG_CACHE_HOME is unset you can assume
                \\this to be
                \\.B
                \\~/.cache/mepo/
                \\
                \\The file
                \\.B
                \\$XDG_CONFIG_HOME/mepo/config
                \\may be used for end-user
                \\configuration and is assumed to be a file with valid mepolang
                \\syntax. If $XDG_CONFIG_HOME is unset you can assume this
                \\to be
                \\.B
                \\~/.config/mepo/config
                \\.
                ,
                .{}
            );

            try stdout.print(
                \\
                \\.SH MEPOLANG
                \\
                \\Mepolang is mepo's comand language for runtime IPC and configuration. It
                \\takes the form of a plain-text DSL (domain-specific-language) with a
                \\number of commands. Mepolang makes configuration, customizing,
                \\and hacking on mepo simple. To test mepolang simply, you may run mepo
                \\with the `-i` argument which reads mepolang from STDIN. A basic
                \\example might look like:
                \\
                \\echo "prefset_n crosshair_size 200;" | mepo -i
                \\
                \\.SH MEPOLANG SYNTAX
                \\
                \\Syntax rules are as follows:
                \\
                \\1. Mepolang syntax is composed of statements.
                \\
                \\2. Each statement is made up of multiple tokens and terminated by a semicolon.
                \\
                \\3. Tokens are separated by whitespace.
                \\
                \\4. The first token in a statement is always the command name.
                \\
                \\5. Each token is either:
                \\
                \\5A. **Text:** Just plain text, by default assumed to be a single word.
                \\If you want to use a space within an token use `[ square brackets ]`
                \\to create a multiword token. If you want to have a text token that
                \\looks like a number, use square brackets like `[-3]`.
                \\
                \\5B. **Number:** A floating point number, either decimal (e.g. `3.77`)
                \\or whole (e.g. `3`). Can be negative like `-22.22` or positive
                \\like `22.22`.
                \\
                \\Example mepolang text:
                \\  commandname textarg [multi word arg] 2;
                \\  commandname2 arg 8.373 anothertextarg;
                \\
                ,
                .{}
            );

            try stdout.print(".SH MEPOLANG COMMANDS\n", .{});
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
                \\.SH Base Configuration
                \\.PP
                \\{s}
                \\
                \\.PP
                \\{s}
                \\
                \\.SH VERSION
                \\This manual page has been generated against mepo version {s}
                \\
                \\.SH AUTHORS
                \\Mepo is written by Miles Alan <m@milesalan.com>.
                \\
                \\A full list of contributors can be seen in git shortlog.
                \\
                \\.SH CONTRIBUTING
                \\Bugs, patches, and feature discussions can be sent to ~mil/mepo-devel@lists.sr.ht.
                \\
                \\For more information on Mepo and contributing, view mepo's
                \\website at http://mepo.milesalan.com or mepo's project page
                \\on srht at http://sr.ht/~mil/mepo
                \\
                ,
                .{DocBaseConfigIntro, config.DefaultBaseConfig, config.Version}
            );
        },
    }
}

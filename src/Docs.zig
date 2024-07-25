const std = @import("std");
const FnTable = @import("./api/_FnTable.zig");
const config = @import("./config.zig");
const utilprefs = @import("./util/utilprefs.zig");

pub const CliFlags = &[_]struct {
    flag: []const u8,
    param: ?[]const u8 = null,
    desc: []const u8,
}{
    .{ .flag = "-docmd", .desc = "Print markdown documentation for the JSON API to STDOUT." },
    .{ .flag = "-i", .desc = "Read JSON commands from STDIN continually (newline seperated). Can be used for interactive debugging or scripting via: `tee | mepo -i` or `./myscript | mepo -i`." },
    .{ .flag = "-e", .desc = "Enable debug mode to log messages to STDERR." },
    .{ .flag = "-hw", .desc = "Force using hardware renderer rather then default auto (HW/SW) renderer." },
    .{ .flag = "-sw", .desc = "Force using software renderer rather then default auto (HW/SW) renderer." },
    .{ .flag = "-tx", .desc = "Number of textures to load to (GPU) memory for both OSM & pile tile layer cache (defaults to 200).", .param = "#" },
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

const JSONAPIIntro =
    \\
    \\Mepo offers an extensive JSON API which is utilized for user
    \\configuration (via ~/.config/mepo/config.json), savestates (via
    \\~/.cache/mepo/savestate.json), and can be used for arbitrary scripting
    \\and end-user customization.
    \\
    \\
    \\The basic syntax for the JSON API is that anywhere JSON API commands
    \\may be passed, you can pass an array of commands as:
    \\
    \\```sh
    \\[
    \\  {"cmd": "command_name", "args": {"arg_name": "arg_value"}},
    \\  {"cmd": "command_name2", "args": {"arg_name": "arg_value"}}
    \\]
    \\```
    \\
    \\For a quickstart on how to use the JSON API practically, see
    \\the [scripting guide](/scriptingguide.html).
;


const DocEnvVarsShellpipe =
    \\Both `shellpipe_sync` and `shellpipe_async` expose a number of ENV
    \\variables to the target script called. See below for the accessible
    \\ENV variables exposed.
    \\
    \\- `MEPO_WIN_W`: Width of the UI window
    \\- `MEPO_WIN_H`: Height of the UI window
    \\- `MEPO_ZOOM`: Current zoom level
    \\- `MEPO_CENTER_LAT`: Latitude of the center point of the screen
    \\- `MEPO_CENTER_LON`: Longitude of the center point of the screen
    \\- `MEPO_TL_LAT`: Latitude of the top left point on the screen
    \\- `MEPO_TL_LON`: Longitude of the top left point on the screen
    \\- `MEPO_BR_LAT`: Latitude of the bottom right point on the screen
    \\- `MEPO_BR_LON`: Longitude of the bottom right point on the screen
    \\- `MEPO_CURSOR_LAT`: Latitude of the cursor position
    \\- `MEPO_CURSOR_LON`: Longitude of the cursor position
;

const DocBaseConfigIntro =
    \\The following base configuration was built into Mepo as of
    \\the current release version. Note, preferences can
    \\be overridden directly for example with `prefset_n` and
    \\`prefset_t`.
;

pub fn generateMarkdownDocs(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\# JSON API
        \\
        \\<div class='toc'>
        \\<ul>
        \\<li><a href="#overview">Overview</a></li>
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
    , .{ JSONAPIIntro, config.Version });

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
        .{PrefsIntro},
    );
    try stdout.print(
        \\| **Name** | **Description** | **Datatype** | **Min** | **Max** | **Default Value** |
        \\| -------- | --------------- | ------------ | ------- | ------- | ----------------- |
        \\
    , .{});
    for (utilprefs.prefs_mapping) |pref| {
        const datatype = switch (pref.value) {
            .b => "Number (bool)",
            .t => "Text",
            .f => "Number (float)",
            .u => "Number (u8)",
            .u24 => "Number (u24)",
        };

        var value: []const u8 = "";
        switch (pref.value) {
            .t => {
                const text = if (pref.value.t) |t| t else "";
                value = try std.fmt.allocPrint(allocator, "{s}", .{text});
            },
            .b => {
                if (pref.value.b) {
                    value = try std.fmt.allocPrint(allocator, "{d}", .{1});
                } else {
                    value = try std.fmt.allocPrint(allocator, "{d}", .{0});
                }
            },
            .f => {
                value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.f});
            },
            .u => {
                value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.u});
            },
            .u24 => {
                value = try std.fmt.allocPrint(allocator, "{d}", .{pref.value.u24});
            },
        }
        defer allocator.free(value);

        if (pref.bounds) |bounds| {
            try stdout.print("| {s} | {s} | {s} | {d} | {d} | {s} |\n", .{ pref.name, pref.desc, datatype, bounds.min, bounds.max, value });
        } else {
            try stdout.print("| {s} | {s} | {s} |  |  | {s} |\n", .{ pref.name, pref.desc, datatype, value });
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
        .{ DocEnvVarsShellpipe, DocBaseConfigIntro, config.DefaultBaseConfig },
    );
}

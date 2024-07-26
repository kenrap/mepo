const std = @import("std");
const sdl = @import("./sdlshim.zig");
const types = @import("./types.zig");
const config = @import("./config.zig");
const errors = @import("./errors.zig");
const TileCache = @import("./TileCache.zig");
const blitfns = @import("./blit/blit.zig");
const utilconversion = @import("./util/utilconversion.zig");
const utilplatform = @import("util/utilplatform.zig");
const p = @import("util/utilprefs.zig");
const utildbg = @import("util/utildbg.zig");
const utilsdl = @import("util/utilsdl.zig");
const datastructure = @import("datastructure/datastructure.zig");
const zoom_relative = @import("./api/zoom_relative.zig").zoom_relative;
const FnTable = @import("./api/_FnTable.zig");

allocator: std.mem.Allocator,
async_shellpipe_threads: datastructure.QueueHashMap(i8, sdl.SDL_threadID),
blit_pinlayer_cache: datastructure.EvictionHashMap(types.XYZ, *sdl.SDL_Texture, evict_texture, &config.MaxTextures),
config: []const u8,
debug_message: ?[]const u8 = null,
drag: ?struct {
    begin_ticks: u32,
    point: sdl.SDL_Point,
    delta_x: u32 = 0,
    delta_y: u32 = 0,
} = null,
initialized_video: std.Thread.ResetEvent,
fingers: std.ArrayList(sdl.SDL_FingerID),
fingers_gesture_delta: isize = 0,
fonts_normal: [50]*sdl.TTF_Font,
fonts_bold: [50]*sdl.TTF_Font,
pin_group_active: u8 = 0,
pin_group_active_item: ?u32 = null,
pin_groups: [10]std.ArrayList(types.Pin) = undefined,
renderer: *sdl.SDL_Renderer = undefined,
renderer_type: types.RendererType = .Auto,
table_gestures: std.array_hash_map.AutoArrayHashMap(types.GestureInput, []const u8),
table_clicks: std.array_hash_map.AutoArrayHashMap(types.ClickInput, []const u8),
table_keybindings: std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8),
table_signals: std.array_hash_map.AutoArrayHashMap(u6, []const u8),
table_timers: std.array_hash_map.AutoArrayHashMap(types.TimerInput, []const u8),
tile_cache: *TileCache,
title_update_ms: usize = 0,
uibuttons: std.ArrayList(types.UIButton),
win_h: u32 = config.InitWindowH,
win_w: u32 = config.InitWindowW,
window: *sdl.SDL_Window = undefined,
quit_action: ?[]const u8 = null,

pub fn convert_latlon_to_xy(mepo: *@This(), lat_or_lon: enum { LonToX, LatToY }, lat_lon_value: f64) i32 {
    return switch (lat_or_lon) {
        .LonToX => -1 * (mepo.get_x() - @as(i32, @intCast(mepo.win_w / 2)) - utilconversion.lon_to_px_x(lat_lon_value, p.get(p.pref.zoom).u)),
        .LatToY => -1 * (mepo.get_y() - @as(i32, @intCast(mepo.win_h / 2)) - utilconversion.lat_to_px_y(lat_lon_value, p.get(p.pref.zoom).u)),
    };
}

fn event_fingerdown(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    for (mepo.fingers.items) |f| if (e.tfinger.fingerId == f) return .None;
    mepo.fingers.append(e.tfinger.fingerId) catch unreachable;
    if (mepo.fingers.items.len > 1) mepo.fingers_gesture_delta = 0;
    return .None;
}

fn event_fingerup(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    for (mepo.fingers.items, 0..) |f, i| {
        if (e.tfinger.fingerId == f) {
            _ = mepo.fingers.orderedRemove(i);
            break;
        }
    }
    if (mepo.fingers.items.len == 2) mepo.fingers_gesture_delta = 0;
    return .None;
}

fn event_textinput(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    var idx: usize = 0;
    var pending: types.Pending = .None;
    const text = e.text.text;
    while (text[idx] != 0) : (idx += 1) {
        const char_z: [2]u8 = .{ std.ascii.toLower(text[idx]), 0 };
        const key = types.KeyInput{
            .keymod = if (std.ascii.isUpper(text[idx])) sdl.KMOD_LSHIFT | sdl.KMOD_RSHIFT else 0,
            .key = char_z[0],
        };
        if (mepo.table_keybindings.get(key)) |run_expression| {
            utildbg.log("Got keybindings table function via textinput with run expression: <{s}>\n", .{run_expression});
            mepo.jsonapi_execute(run_expression) catch unreachable;
            pending = .Redraw;
        }
    }
    return pending;
}

fn event_multigesture(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    const threshold_pan_dist = 0.004;
    const threshold_rotate_radians = 0.015;

    const delta_max = 2;
    const run_gesture_opt: ?types.GestureInput = run_gesture: {
        if (e.mgesture.dDist > threshold_pan_dist) {
            break :run_gesture .{ .action = .Pan, .direction = .In, .n_fingers = @intCast(mepo.fingers.items.len) };
        } else if (e.mgesture.dDist < -threshold_pan_dist) {
            break :run_gesture .{ .action = .Pan, .direction = .Out, .n_fingers = @intCast(mepo.fingers.items.len) };
        } else if (e.mgesture.dTheta > threshold_rotate_radians) {
            break :run_gesture .{ .action = .Rotate, .direction = .In, .n_fingers = @intCast(mepo.fingers.items.len) };
        } else if (e.mgesture.dTheta < -threshold_rotate_radians) {
            break :run_gesture .{ .action = .Rotate, .direction = .Out, .n_fingers = @intCast(mepo.fingers.items.len) };
        }
        break :run_gesture null;
    };

    if (run_gesture_opt) |run_gesture| run: {
        if (run_gesture.direction == .In and mepo.fingers_gesture_delta == delta_max) break :run;
        if (run_gesture.direction == .Out and mepo.fingers_gesture_delta == -delta_max) break :run;
        mepo.fingers_gesture_delta += @as(isize, if (run_gesture.direction == .In) 1 else -1);
        if (mepo.table_gestures.get(run_gesture)) |run_expression| {
            utildbg.log("Got gestures table function with run expression: <{s}>\n", .{run_expression});
            mepo.jsonapi_execute(run_expression) catch unreachable;
        }
        return .Redraw;
    }

    return .None;
}

fn event_mousebuttondown(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.fingers.items.len > 1) return .None;

    const cursor = mepo.scaled_mouse_position();
    if (!mepo.within_touch_bounds(cursor.x, cursor.y)) {
        mepo.drag = null;
        return .None;
    } else if (e.button.button == sdl.SDL_BUTTON_LEFT) {
        mepo.drag = .{
            .begin_ticks = sdl.SDL_GetTicks(),
            .point = .{ .x = cursor.x, .y = cursor.y },
        };
    }
    return .Redraw;
}

fn event_mousebuttonup(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.fingers.items.len > 1) return .None;
    defer mepo.drag = null;

    const cursor = mepo.scaled_mouse_position();

    // 1. Invalidation checks: ensure not out of bounds or not dragging
    {
        const is_outside_touch_bounds = !mepo.within_touch_bounds(cursor.x, cursor.y);
        const is_dragging = mepo.drag != null and
            mepo.drag.?.delta_x + mepo.drag.?.delta_y > 10;
        if (is_outside_touch_bounds or is_dragging) return .None;
    }

    // 2. UI on elements clcking overrides (uibtns)
    //    these actions take preference *over* bind_click actions
    if (blitfns.blit_uibuttons(mepo, cursor) catch null) |clicked_btn| {
        // Click on UI button check
        utildbg.log("Clicked on button: {} with clicks {}\n", .{ clicked_btn, e.button.clicks });
        mepo.jsonapi_execute(clicked_btn.jsonapi_click_single) catch unreachable;
        return .Redraw;
    }

    // 3. Click pin to activate for a single click
    if (e.button.clicks == 1) {
        // Click pin to activate check
        var closest_match_pin: ?struct {
            pin_group_i: u8,
            pin_i: u32,
            delta_dist: u32,
        } = null;
        for (mepo.pin_groups, 0..) |pin_group, pin_group_i| {
            for (pin_group.items, 0..) |*item, pin_i| {
                if (item.category == .Structural) continue;
                const pin_x = mepo.convert_latlon_to_xy(.LonToX, item.lon);
                const pin_y = mepo.convert_latlon_to_xy(.LatToY, item.lat);
                const delta = @abs(pin_x - cursor.x) + @abs(pin_y - cursor.y);
                if (delta < config.ClickPinMaxDelta and (closest_match_pin == null or closest_match_pin.?.delta_dist > delta)) {
                    closest_match_pin = .{
                        .pin_group_i = @intCast(pin_group_i),
                        .pin_i = @intCast(pin_i),
                        .delta_dist = delta,
                    };
                }
            }
        }
        if (closest_match_pin) |match| {
            mepo.pin_group_active = match.pin_group_i;
            mepo.pin_group_active_item = match.pin_i;
            mepo.blit_pinlayer_cache.clearAndFree();
            return .Redraw;
        }
    }

    // 4. Default back to whatever was bound on bind_click by user
    const key = types.ClickInput{ .button = e.button.button, .clicks = @intCast(e.button.clicks) };
    if (mepo.table_clicks.get(key)) |run_expression| {
        utildbg.log("Got click table function {s} for {}\n", .{ run_expression, key });
        mepo.jsonapi_execute(run_expression) catch unreachable;
        return .Redraw;
    }

    return .None;
}

fn event_mousemotion(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.fingers.items.len > 1) return .None;

    const cursor = mepo.scaled_mouse_position();
    if (mepo.drag != null and mepo.within_touch_bounds(cursor.x, cursor.y)) {
        mepo.drag.?.point.x = cursor.x;
        mepo.drag.?.point.y = cursor.y;
        mepo.drag.?.delta_x += @abs(e.motion.xrel);
        mepo.drag.?.delta_y += @abs(e.motion.yrel);
        mepo.set_x(mepo.get_x() - (e.motion.xrel * p.get(p.pref.drag_scale).u));
        mepo.set_y(mepo.get_y() - (e.motion.yrel * p.get(p.pref.drag_scale).u));
        return .Drag;
    } else {
        mepo.drag = null;
    }
    return .None;
}

fn within_touch_bounds(mepo: *@This(), x: c_int, y: c_int) bool {
    return x > 0 and y > 0 and x < mepo.win_w and y < mepo.win_h;
}

fn event_mousewheel(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    zoom_relative(mepo, e.wheel.y);
    return .Redraw;
}

fn event_keyup(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (sdl.SDL_TRUE == sdl.SDL_IsTextInputActive() and
        e.key.keysym.mod == 0) return .None;
    const key = sdl.SDL_GetScancodeName(e.key.keysym.scancode);
    utildbg.log("Processing key in keyup: {s}\n", .{key});

    // E.g. don't process anything but single-character hits
    // so things like "Left Shift" etc. are skipped
    if (std.mem.indexOfSentinel(u8, 0, key) != 1) return .None;

    if (mepo.table_keybindings.get(.{
        .key = std.ascii.toLower(key[0]),
        .keymod = keymod: {
            // E.g. within bind_key we store modifiers as KMOD_SHIFT rather then both KMOD_{L,R}SHIFT
            // KMOD_SHIFT is actually (KMOD_LSHIFT | KMOD_RSHIFT)
            // So here we just expand the bitset so the right/left inverse variant is set
            // as such right / left {shift,ctrl,alt} mods always act the same regardless
            var bitset = e.key.keysym.mod;
            for (&[_][2]u16{
                [2]u16{ sdl.KMOD_LSHIFT, sdl.KMOD_RSHIFT },
                [2]u16{ sdl.KMOD_LCTRL, sdl.KMOD_RCTRL },
                [2]u16{ sdl.KMOD_LALT, sdl.KMOD_RALT },
            }) |lr_set| {
                if (bitset & lr_set[0] == lr_set[0]) bitset |= lr_set[1];
                if (bitset & lr_set[1] == lr_set[1]) bitset |= lr_set[0];
            }
            break :keymod bitset;
        },
    })) |run_expression| {
        utildbg.log("Got keybindings table function via keyup with run expression: <{s}>\n", .{run_expression});
        mepo.jsonapi_execute(run_expression) catch unreachable;
        return .Redraw;
    }
    return .None;
}

fn event_signal(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    if (mepo.table_signals.get(@intCast(e.user.code))) |run_expression| {
        utildbg.log("Got signals table function {s}\n", .{run_expression});
        mepo.jsonapi_execute(run_expression) catch unreachable;
        return .Redraw;
    }
    return .None;
}

fn event_windowevent(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    // Fix for certain platforms like Phosh like open keyboard on winevents
    defer if (utilplatform.supports_osk()) sdl.SDL_StopTextInput();

    switch (e.window.event) {
        sdl.SDL_WINDOWEVENT_FOCUS_GAINED => {
            sdl.SDL_RaiseWindow(mepo.window);
        },
        sdl.SDL_WINDOWEVENT_RESIZED => {
            var gl_width: c_int = undefined;
            var gl_height: c_int = undefined;
            sdl.SDL_GL_GetDrawableSize(mepo.window, &gl_width, &gl_height);
            utilsdl.errorcheck(sdl.SDL_RenderSetLogicalSize(mepo.renderer, gl_width, gl_height)) catch |err| {
                utildbg.log("Unable to set logical size: {}\n", .{err});
            };
            mepo.win_w = @intCast(gl_width);
            mepo.win_h = @intCast(gl_height);
        },
        else => {
            //utildbg.log("Unhandled SDL Window Event: {s}\n", .{@tagName(@intToEnum(sdl.SDL_WindowEventID, @intCast(c_int, e.window.event)))});
        },
    }

    return .Redraw;
}

fn event_jsonapiexecution(mepo: *@This(), e: sdl.SDL_Event) types.Pending {
    const heap_str = std.mem.sliceTo(@as([*c]u8, @ptrCast(e.user.data1)), 0);
    utildbg.log("SDL jsonapi event proccessing: <{s}>\n", .{heap_str});
    mepo.jsonapi_execute(heap_str) catch |err| {
        utildbg.log("Error executing JSON API expression <{s}> caught from SDL event: {}\n", .{ heap_str, err });
    };
    mepo.allocator.free(heap_str);
    return .Redraw;
}

pub fn event_quit(mepo: *@This(), _: sdl.SDL_Event) types.Pending {
    if (mepo.quit_action) |quit_action| {
        mepo.jsonapi_execute(quit_action) catch |err| {
            utildbg.log("Error with running jsonapi quit action: {}\n", .{err});
        };
    }
    graceful_terminate_sdl();
    return .None;
}

fn event_unhandled(_: *@This(), e: sdl.SDL_Event) types.Pending {
    //utildbg.log("Unhandled SDL Event: {s}\n", .{@tagName(@intToEnum(sdl.SDL_EventType, @intCast(c_int, e.type)))});
    _ = e;
    return .None;
}

fn evict_texture(_: types.XYZ, texture: *sdl.SDL_Texture) void {
    sdl.SDL_DestroyTexture(texture);
}

fn jsonapi_execute_parseargs(
    allocator: std.mem.Allocator,
    fn_spec_args: []const types.MepoFnSpecArg,
    map: std.json.ArrayHashMap(std.json.Value),
) anyerror![types.MepoFnNargs]types.MepoArg {
    var args: [types.MepoFnNargs]types.MepoArg = undefined;
    for (fn_spec_args, 0..) |spec_arg, i| {
        if (map.map.get(spec_arg.name)) |arg| {
            switch (arg) {
                .float => |parsedFloat| {
                    if (spec_arg.tag != .Number) return error.InvalidArgTypeGotFloat;
                    args[i] = .{ .Number = parsedFloat };
                },
                .integer => |parsedInt| {
                    if (spec_arg.tag != .Number) return error.InvalidArgTypeGotInt;
                    args[i] = .{ .Number = @floatFromInt(parsedInt) };
                },
                .string => |parsedText| {
                    if (spec_arg.tag != .Text) return error.InvalidArgTypeGotText;
                    args[i] = .{ .Text = try allocator.dupeZ(u8, parsedText) };
                },
                .array => |g| {
                    if (spec_arg.tag != .Exps) return error.InvalidArgTypeGotExps;
                    const str = try std.json.stringifyAlloc(allocator, g.items, .{});
                    args[i] = .{ .Exps = str };
                },
                else => return error.InvalidArgsTypeGotUnknown,
            }
        } else if (spec_arg.default_value) |val| {
            args[i] = val;
        } else {
            utildbg.log("Missing argument {s} for spec\n", .{spec_arg.name});
            return error.MissingArgForSpec;
        }
    }
    return args;
}

pub fn jsonapi_execute(mepo: *@This(), jsonapi_text: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(mepo.allocator);
    defer arena.deinit();

    const Statement = struct {
        cmd: []u8,
        args: std.json.ArrayHashMap(std.json.Value),
    };
    const parsed = std.json.parseFromSlice(std.json.Value, arena.allocator(), jsonapi_text, .{}) catch |e| {
        utildbg.log("Attempted to parse Mepo JSON API - provided invalid JSON: {} / {s}\n", .{ e, jsonapi_text });
        return;
    };

    switch (parsed.value) {
        .array => |value| {
            for (value.items) |v| {
                const p2 = std.json.parseFromValue(Statement, std.heap.page_allocator, v, .{}) catch |e| {
                    utildbg.log("JSON Value parse error for mepo statement: {} / {}\n", .{ e, v });
                    return;
                };
                const cmd = p2.value.cmd;
                if (FnTable.get(cmd)) |fn_spec| {
                    const args = jsonapi_execute_parseargs(std.heap.page_allocator, fn_spec.args, p2.value.args) catch |args_error| {
                        std.debug.print("Error parsing args for {s} ({any}): {}\n", .{ cmd, p2.value.args, args_error });
                        return;
                    };
                    std.debug.print("Run cmd: {s} with args: {any}\n", .{ cmd, args });
                    fn_spec.execute(mepo, args) catch |jsonapi_err| {
                        utildbg.log("Error running API function for: {s}: {}\n", .{ cmd, jsonapi_err });
                    };
                    try mepo.update_debug_message(null);
                } else {
                    utildbg.log("Invalid JSON cmd specified: {s}", .{cmd});
                }
            }
        },
        else => {
            utildbg.log("Attempted to parse Mepo JSON API commands but not an array: {s}", .{jsonapi_text});
        },
    }
}

fn dispatch_check_click_hold(mepo: *@This()) void {
    if (mepo.drag == null or mepo.fingers.items.len > 1) {
        mepo.drag = null;
        return;
    }

    const threshold_hit_hold_ms = sdl.SDL_GetTicks() >= mepo.drag.?.begin_ticks + config.DragThresholdTicks;
    const threshold_hit_distance = mepo.drag.?.delta_x + mepo.drag.?.delta_y <= config.DragThresholdDelta;

    // Dispatch held action
    if (threshold_hit_distance) {
        if (blitfns.blit_uibuttons(mepo, mepo.drag.?.point) catch null) |held_btn| {
            if (threshold_hit_hold_ms) {
                utildbg.log("Held on button: {}\n", .{held_btn});
                mepo.jsonapi_execute(held_btn.jsonapi_click_hold) catch unreachable;
                mepo.drag = null;
            }
            return;
        }
    }

    if (threshold_hit_hold_ms and threshold_hit_distance) {
        mepo.drag = null;
        // TODO: hold support for right click as well?
        if (mepo.table_clicks.get(.{ .button = sdl.SDL_BUTTON_LEFT, .clicks = -1 })) |run_expression| {
            utildbg.log("Got hold table function {s} after dispatch time\n", .{run_expression});
            mepo.jsonapi_execute(run_expression) catch unreachable;
            utilsdl.sdl_push_event_resize();
        }
    }
}

fn dispatch_check_timers(mepo: *@This()) !void {
    var it = mepo.table_timers.iterator();
    while (it.next()) |kv| {
        const timer_input = kv.key_ptr.*;
        const timer_jsonapi = kv.value_ptr.*;
        if (sdl.SDL_GetTicks() > timer_input.created_at_ticks + (timer_input.interval_seconds * 1000)) {
            mepo.jsonapi_execute(timer_jsonapi) catch unreachable;
            const new_timer = .{
                .created_at_ticks = sdl.SDL_GetTicks(),
                .interval_seconds = timer_input.interval_seconds,
            };
            _ = mepo.table_timers.swapRemove(timer_input);
            try mepo.table_timers.put(new_timer, timer_jsonapi);
        }
    }
}

pub fn init_video_and_sdl_stdin_loop(mepo: *@This(), enable_stdin_jsonapi_repl: bool) !void {
    if (enable_stdin_jsonapi_repl) {
        const thread = sdl.SDL_CreateThread(
            mepo_sdl_loop_thread_boot,
            "Mepo_SDL_Thread",
            mepo,
        );
        sdl.SDL_DetachThread(thread);

        mepo.initialized_video.wait();
        const stdin = &std.io.getStdIn().reader();
        while (true) {
            const read_slice: []const u8 = stdin.readUntilDelimiterAlloc(mepo.allocator, '\n', 102400) catch continue;
            const slice_z = try mepo.allocator.dupeZ(u8, read_slice);
            mepo.allocator.free(read_slice);
            std.debug.print("Read {d} bytes, running input as jsonapi\n", .{slice_z.len});
            utilsdl.sdl_push_event_jsonapi_execution(slice_z);
        }
    } else {
        _ = mepo_sdl_loop_thread_boot(mepo);
    }
}

fn mepo_sdl_loop_thread_boot(userdata: ?*anyopaque) callconv(.C) c_int {
    const mepo: *@This() = @alignCast(@ptrCast(userdata.?));
    video_init(mepo) catch unreachable;
    mepo.jsonapi_execute(mepo.config) catch unreachable;
    mepo.initialized_video.set();
    sdl_event_loop(mepo) catch unreachable;
    return 0;
}

pub fn sdl_event_loop(mepo: *@This()) !void {
    var pending: types.Pending = .None;
    var e: sdl.SDL_Event = undefined;

    while (true) {
        // Redraw
        sdl.SDL_PumpEvents();
        const has_pending_motion_events = (sdl.SDL_TRUE == sdl.SDL_HasEvent(sdl.SDL_MOUSEMOTION));
        if ((!has_pending_motion_events and pending == .Drag) or pending == .Redraw) {
            try mepo.blit();
        }

        mepo.dispatch_check_click_hold();
        try mepo.dispatch_check_timers();

        // Process SDL events
        if (sdl.SDL_WaitEventTimeout(&e, config.DragThresholdTicks) > 0) {
            const pending_fn = switch (e.type) {
                sdl.SDL_FINGERDOWN => &event_fingerdown,
                sdl.SDL_FINGERUP => &event_fingerup,
                sdl.SDL_KEYUP => &event_keyup,
                sdl.SDL_MOUSEBUTTONDOWN => &event_mousebuttondown,
                sdl.SDL_MOUSEBUTTONUP => &event_mousebuttonup,
                sdl.SDL_MOUSEMOTION => &event_mousemotion,
                sdl.SDL_MOUSEWHEEL => &event_mousewheel,
                sdl.SDL_MULTIGESTURE => &event_multigesture,
                sdl.SDL_TEXTINPUT => &event_textinput,
                sdl.SDL_QUIT => &event_quit,
                sdl.SDL_WINDOWEVENT => &event_windowevent,
                else => b: {
                    // Async events triggered outside of main thread:
                    // 1) signals & 2) jsonapi trigged via shellpipe or STDIN
                    if (e.type == utilsdl.sdl_usereventtype(.JSONAPI)) break :b &event_jsonapiexecution;
                    if (e.type == utilsdl.sdl_usereventtype(.Signal)) break :b &event_signal;
                    // Unhandled case
                    break :b &event_unhandled;
                },
            };

            pending = pending_fn(mepo, e);
        }
    }
}

pub fn update_debug_message(mepo: *@This(), new_msg_opt: ?[]const u8) !void {
    if (mepo.debug_message) |dbg_msg| mepo.allocator.free(dbg_msg);
    if (new_msg_opt) |new_msg| {
        mepo.debug_message = try mepo.allocator.dupe(u8, new_msg);
    } else {
        mepo.debug_message = null;
    }
    utilsdl.sdl_push_event_resize();
}

// Returns the scaled mouse position based on the gl_drawablesize which
// is also set on resizes rather then the raw position which comes in
// from GetMouseState
//
// This is used in several places as its more reliable then motion/button
// events which seem to have some issue with SetLogicalSize in certain
// platforms as of SDL 2.0.22
pub fn scaled_mouse_position(mepo: *@This()) sdl.SDL_Point {
    var cursor_x: c_int = undefined;
    var cursor_y: c_int = undefined;
    var gl_w: c_int = undefined;
    var gl_h: c_int = undefined;
    var win_w: c_int = undefined;
    var win_h: c_int = undefined;
    _ = sdl.SDL_GetMouseState(&cursor_x, &cursor_y);
    sdl.SDL_GL_GetDrawableSize(mepo.window, &gl_w, &gl_h);
    sdl.SDL_GetWindowSize(mepo.window, &win_w, &win_h);
    const scale_x = @as(f64, @floatFromInt(gl_w)) / @as(f64, @floatFromInt(win_w));
    const scale_y = @as(f64, @floatFromInt(gl_h)) / @as(f64, @floatFromInt(win_h));
    const scaled_x = @as(f64, @floatFromInt(cursor_x)) * scale_x;
    const scaled_y = @as(f64, @floatFromInt(cursor_y)) * scale_y;
    return .{ .x = @intFromFloat(scaled_x), .y = @intFromFloat(scaled_y) };
}

pub fn cursor_latlon(mepo: *@This()) struct { Lat: f64, Lon: f64 } {
    const cursor = mepo.scaled_mouse_position();

    const cursor_lat = utilconversion.px_y_to_lat(
        mepo.get_y() - @as(i32, @intCast(mepo.win_h / 2)) + cursor.y,
        p.get(p.pref.zoom).u,
    );
    const cursor_lon = utilconversion.px_x_to_lon(
        mepo.get_x() - @as(i32, @intCast(mepo.win_w / 2)) + cursor.x,
        p.get(p.pref.zoom).u,
    );

    return .{
        .Lat = cursor_lat,
        .Lon = cursor_lon,
    };
}

pub fn get_x(_: *@This()) i32 {
    return utilconversion.lon_to_px_x(p.get(p.pref.lon).f, p.get(p.pref.zoom).u);
}

pub fn get_y(_: *@This()) i32 {
    return utilconversion.lat_to_px_y(p.get(p.pref.lat).f, p.get(p.pref.zoom).u);
}

pub fn set_x(_: *@This(), x: i32) void {
    p.set_n(p.pref.lon, utilconversion.px_x_to_lon(x, p.get(p.pref.zoom).u));
}

pub fn set_y(_: *@This(), y: i32) void {
    p.set_n(p.pref.lat, utilconversion.px_y_to_lat(y, p.get(p.pref.zoom).u));
}

pub fn bounding_box(mepo: *@This()) types.LatLonBox {
    return .{
        .topleft_lat = utilconversion.px_y_to_lat(mepo.get_y() - @as(i32, @intCast(mepo.win_h / 2)), p.get(p.pref.zoom).u),
        .topleft_lon = utilconversion.px_x_to_lon(mepo.get_x() - @as(i32, @intCast(mepo.win_w / 2)), p.get(p.pref.zoom).u),
        .bottomright_lat = utilconversion.px_y_to_lat(mepo.get_y() + @as(i32, @intCast(mepo.win_h / 2)), p.get(p.pref.zoom).u),
        .bottomright_lon = utilconversion.px_x_to_lon(mepo.get_x() + @as(i32, @intCast(mepo.win_w / 2)), p.get(p.pref.zoom).u),
    };
}

pub fn graceful_terminate_sdl() void {
    utildbg.log("Graceful shutdown\n", .{});
    sdl.IMG_Quit();
    sdl.SDL_VideoQuit();
    sdl.SDL_Quit();
    std.posix.exit(0);
}

pub fn sighandle_terminate(arg: c_int) callconv(.C) void {
    utildbg.log("Graceful shutdown via signal: {}", .{arg});
    graceful_terminate_sdl();
}

fn setup_sdl_video_and_window(allocator: std.mem.Allocator) !*sdl.SDL_Window {
    // Dump debug info about SDL version compiled/linked
    {
        const version = v: {
            var v: sdl.SDL_version = undefined;
            sdl.SDL_GetVersion(&v);
            break :v v;
        };
        utildbg.log(
            "Compiled against SDL {s}; linked against SDL {s} (version={d}.{d}.{d})\n",
            .{ sdl.SDL_REVISION, sdl.SDL_GetRevision(), version.major, version.minor, version.patch },
        );
    }

    // Initialize SDL Hints
    {
        // SDL 2.0.22 introduced a new bug where SDL mouse autocapturing
        // causes touch-emulated mouse motion events to not appear.. disabling
        // mouse autocapturing resolves this.
        // See: https://github.com/libsdl-org/SDL/issues/5652
        _ = sdl.SDL_SetHint("SDL_MOUSE_AUTO_CAPTURE", "0");
    }

    // Initialize SDL Image library
    try utilsdl.errorcheck(sdl.IMG_Init(sdl.IMG_INIT_PNG));

    // Initialize SDL video
    video_init: {
        // Attempt to initialize with whatever is set in SDL_VIDEODRIVER
        const env_videodriver_opt = std.process.getEnvVarOwned(allocator, "SDL_VIDEODRIVER") catch null;
        if (env_videodriver_opt) |env_videodriver| env_videoinit: {
            defer allocator.free(env_videodriver);
            const env_videodriver_z = try allocator.dupeZ(u8, env_videodriver);
            defer allocator.free(env_videodriver_z);
            utildbg.log("SDL_VIDEODRIVER env var set to {s}, attempting initialize\n", .{env_videodriver});
            utilsdl.errorcheck(sdl.SDL_VideoInit(&env_videodriver_z[0])) catch |e| {
                utildbg.log("SDL Videodriver {s} failed to initialized: {any}\n", .{ env_videodriver, e });
                break :env_videoinit;
            };
            break :video_init;
        }

        // Use specified order of video drivers to initialize otherwise
        const prefered_sdl_videodrivers_order = &[_][:0]const u8{ "wayland", "x11", "directfb", "kmsdrm" };
        for (prefered_sdl_videodrivers_order) |driver| {
            utildbg.log("SDL Videodriver {s} attempting to initialize\n", .{driver});
            utilsdl.errorcheck(sdl.SDL_VideoInit(&driver[0])) catch |e| {
                utildbg.log("SDL Videodriver {s} failed to initialized: {any}\n", .{ driver, e });
                continue;
            };
            break :video_init;
        }
        utildbg.log("Prefered videodriver failed to initialize; attempting to initializing with default video driver\n", .{});
        try utilsdl.errorcheck(sdl.SDL_VideoInit(null));
    }
    utildbg.log("Successfully initialized SDL with videodriver: {s}\n", .{sdl.SDL_GetCurrentVideoDriver()});

    // Initialize SDL Textinput system
    // Controls input for unicode & IME methods etc.
    // Application logic supports both raw keydowns & textinput
    // Also note wtype on sway produces invalid keycodes in keyup
    // so textinput is required here.
    //
    // The textinput system also controls OSK opening & closing.
    // On Phosh this causes issues since there's an overeagerness to
    // open the OSK with textinput (while in reality only shellpipe
    // scripts need the OSK and besides that onscreen keyboard should
    // be hidden).. so for Phosh we disable textinput
    {
        const textinput_enable = !utilplatform.supports_osk();
        if (textinput_enable) sdl.SDL_StartTextInput() else sdl.SDL_StopTextInput();
        utildbg.log("Setting SDL TextInput system to be enabled?: {}\n", .{textinput_enable});
    }

    // Initialize window
    return window: {
        const w = try utilsdl.errorcheck_ptr(sdl.SDL_Window, sdl.SDL_CreateWindow(
            "mepo",
            sdl.SDL_WINDOWPOS_UNDEFINED,
            sdl.SDL_WINDOWPOS_UNDEFINED,
            config.InitWindowW,
            config.InitWindowH,
            sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_ALLOW_HIGHDPI,
        ));
        if (std.posix.getenv("MEPO_WINDOW_REPOSITION")) |reposition| {
            if (reposition.len == 1 and reposition[0] == '1') {
                sdl.SDL_SetWindowPosition(w, 0, 0);
            }
        }

        // E.g. Phosh sometimes doesn't use all space, e.g. strange bar
        // on bottom; so fullscreen & defullscreen to trigger window resize
        if (utilplatform.xdg_session_desktop() == .Phosh) {
            _ = sdl.SDL_SetWindowFullscreen(w, sdl.SDL_WINDOW_FULLSCREEN);
            _ = sdl.SDL_SetWindowFullscreen(w, 0);
        }

        break :window w;
    };
}

pub fn blit(mepo: *@This()) !void {
    return blitfns.blit(mepo);
}

pub fn video_init(mepo: *@This()) !void {
    mepo.window = try setup_sdl_video_and_window(mepo.allocator);
    mepo.renderer = renderer: {
        const r = try utilsdl.errorcheck_ptr(sdl.SDL_Renderer, sdl.SDL_CreateRenderer(
            mepo.window,
            -1,
            switch (mepo.renderer_type) {
                .Auto => 0,
                .SW => sdl.SDL_RENDERER_SOFTWARE,
                .HW => sdl.SDL_RENDERER_ACCELERATED,
            },
        ));
        break :renderer r;
    };
    var sdl_renderer_info: sdl.SDL_RendererInfo = undefined;
    try utilsdl.errorcheck(sdl.SDL_GetRendererInfo(mepo.renderer, &sdl_renderer_info));
    utildbg.log("Requested renderer driver {}, using renderer: {s}\n", .{ mepo.renderer_type, sdl_renderer_info.name });
    mepo.tile_cache.renderer = mepo.renderer;
}

fn init_create_fonts_array(bold: bool) ![50]*sdl.TTF_Font {
    try utilsdl.errorcheck(sdl.TTF_Init());
    const font_dat = @embedFile("embed_assets/inconsolata.ttf");
    var fonts: [50]*sdl.TTF_Font = undefined;
    var font_size: usize = 0;
    while (font_size < fonts.len) : (font_size += 1) {
        fonts[font_size] = try utilsdl.errorcheck_ptr(
            sdl.TTF_Font,
            sdl.TTF_OpenFontRW(
                sdl.SDL_RWFromConstMem(@ptrCast(&font_dat[0]), font_dat.len),
                1,
                @intCast(font_size),
            ),
        );
        if (bold) sdl.TTF_SetFontStyle(fonts[font_size], sdl.TTF_STYLE_BOLD);
    }
    return fonts;
}

pub fn init(allocator: std.mem.Allocator, tile_cache: *TileCache, use_config: []const u8, renderer_type: types.RendererType) anyerror!@This() {
    return @as(@This(), .{
        .allocator = allocator,
        .blit_pinlayer_cache = datastructure.EvictionHashMap(
            types.XYZ,
            *sdl.SDL_Texture,
            evict_texture,
            &config.MaxTextures,
        ).init(allocator),
        .async_shellpipe_threads = datastructure.QueueHashMap(i8, sdl.SDL_threadID).init(allocator),
        .config = use_config,
        .fonts_normal = try init_create_fonts_array(false),
        .fonts_bold = try init_create_fonts_array(true),
        .fingers = std.ArrayList(sdl.SDL_FingerID).init(allocator),
        .initialized_video = std.Thread.ResetEvent{},
        .table_gestures = std.array_hash_map.AutoArrayHashMap(types.GestureInput, []const u8).init(allocator),
        .table_keybindings = std.array_hash_map.AutoArrayHashMap(types.KeyInput, []const u8).init(allocator),
        .table_clicks = std.array_hash_map.AutoArrayHashMap(types.ClickInput, []const u8).init(allocator),
        .table_signals = std.array_hash_map.AutoArrayHashMap(u6, []const u8).init(allocator),
        .table_timers = std.array_hash_map.AutoArrayHashMap(types.TimerInput, []const u8).init(allocator),
        .pin_groups = pin_groups: {
            var pgs: [10]std.ArrayList(types.Pin) = undefined;
            for (pgs, 0..) |_, i| pgs[i] = std.ArrayList(types.Pin).init(allocator);
            break :pin_groups pgs;
        },
        .tile_cache = tile_cache,
        .uibuttons = std.ArrayList(types.UIButton).init(allocator),
        .renderer_type = renderer_type,
    });
}

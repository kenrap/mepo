const std = @import("std");
const types = @import("../types.zig");

/// Converts a list of tokens into a list of args decoded to proper
/// union types.
///
/// Caller is responsible for freeing returned memory for heap allocated
/// text args
pub fn mepolang_argize(allocator: *std.mem.Allocator, tokens: []const []const u8) ![types.MepoFnNargs]types.MepoArg {
    var args_i: usize = 0;
    var args: [types.MepoFnNargs]types.MepoArg = undefined;
    var i: usize = 0;
    var bracket_start_i: usize = undefined;
    var bracket_nest_n: usize = 0;

    for (tokens) |tok| {
        if (tok[0] == '[' and tok.len == 1) bracket_nest_n += 1;
        if (tok[0] == ']' and tok.len == 1) bracket_nest_n -= 1;

        if (bracket_nest_n == 1 and tok[0] == '[' and tok.len == 1) {
            bracket_start_i = i;
        } else if (bracket_nest_n == 0 and tok[0] == ']' and tok.len == 1) {
            args[args_i] = .{ .Text = try std.mem.joinZ(allocator, " ", tokens[bracket_start_i + 1 .. i]) };
            args_i += 1;
        } else if (bracket_nest_n >= 1) {
            // nop
        } else if ((tok[0] == '-' and tok.len > 1) or (tok[0] >= '0' and tok[0] <= '9')) {
            args[args_i] = .{ .Number = try std.fmt.parseFloat(f64, tok) };
            args_i += 1;
        } else {
            args[args_i] = .{ .Text = try allocator.dupeZ(u8, tok) };
            args_i += 1;
        }
        i += 1;
    }

    return args;
}

test "mepolang_argize" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const spec = struct {
        input: []const []const u8,
        expect: []const types.MepoArg,
    };

    var specs = [_]spec{
        .{
            // Standard check to make sure text / numbers argized properly
            .input = &[_][]const u8{ "arga", "22.2" },
            .expect = &[_]types.MepoArg{
                types.MepoArg{ .Text = "arga" },
                types.MepoArg{ .Number = 22.2 },
            },
        },
        .{
            // Numbers check (negative, postive)
            .input = &[_][]const u8{ "-22.4", "2747.2716" },
            .expect = &[_]types.MepoArg{
                types.MepoArg{ .Number = -22.4 },
                types.MepoArg{
                    .Number = 2747.2716,
                },
            },
        },
        .{
            // Ensure argizer never parses past 1st set of string, e.g. nested []
            // should just tokenize as single arg proc
            .input = &[_][]const u8{ "foo", "bar", "[", "baz", "bill", "]", "dill", "jill" },
            .expect = &[_]types.MepoArg{ types.MepoArg{ .Text = "foo" }, types.MepoArg{ .Text = "bar" }, types.MepoArg{ .Text = "baz bill" }, types.MepoArg{ .Text = "dill" } },
        },
    };

    for (specs) |s| {
        const result = try mepolang_argize(&arena.allocator, s.input[0..]);
        for (s.expect) |_, i| {
            try std.testing.expectEqual(@TypeOf(s.expect[i]), @TypeOf(result[i]));
            switch (result[i]) {
                .Number => try std.testing.expectEqual(s.expect[i].Number, result[i].Number),
                .Text => try std.testing.expectEqualSlices(u8, s.expect[i].Text, result[i].Text),
            }
        }
    }
}

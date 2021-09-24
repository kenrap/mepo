const std = @import("std");

pub fn tokenize(allocator: *std.mem.Allocator, patch_str: []const u8) ![][]const u8 {
    var token_it = std.mem.tokenize(patch_str, " \n");
    var tokens: [][]const u8 = try allocator.alloc([]const u8, 10000);
    var tokens_size: u32 = 0;

    while (true) {
        var item = token_it.next();
        if (item == null) break;
        var trimmed = std.mem.trim(u8, item.?, " \n");
        if (trimmed.len < 1) continue;
        tokens[tokens_size] = trimmed;
        tokens_size += 1;

        // Starting delims
        while (tokens[tokens_size - 1][0] == '[') {
            if (tokens[tokens_size - 1].len == 1) break;
            tokens[tokens_size] = tokens[tokens_size - 1][1..];
            tokens[tokens_size - 1] = tokens[tokens_size - 1][0..1];
            tokens_size += 1;
        }

        // Ending delims
        var origpos = tokens_size - 1;
        while (tokens[origpos].len > 1 and tokens[origpos][tokens[origpos].len - 1] == ']') {
            tokens[tokens_size] = tokens[origpos][tokens[origpos].len - 1 .. tokens[origpos].len];
            tokens[origpos] = tokens[origpos][0 .. tokens[origpos].len - 1];
            tokens_size += 1;
        }
        std.mem.reverse([]const u8, tokens[origpos + 1 .. tokens_size]);
    }
    return tokens[0..tokens_size];
}

pub fn statementize(allocator: *std.mem.Allocator, input: []const u8) ![][][]const u8 {
    var statement_it = std.mem.tokenize(input, ";");
    var statements = std.ArrayList([][]const u8).init(allocator);

    while (true) {
        var item = statement_it.next();
        if (item == null) break;
        var toks = try tokenize(allocator, item.?);
        if (toks.len < 1) continue;
        try statements.append(toks);
    }

    return statements.items;
}

pub fn read_stdin(allocator: *std.mem.Allocator) anyerror![]const u8 {
    const stream = &std.io.getStdIn().reader();
    var buffer = try allocator.alloc(u8, 1024 * 100);
    std.debug.warn("Waiting for STDIN\n", .{});
    _ = try stream.read(buffer);
    return std.mem.trim(u8, buffer, " \n");
}

pub fn read_args_str(allocator: *std.mem.Allocator) anyerror![]u8 {
    var args_it = std.process.args();
    var accumulate = try allocator.alloc(u8, 0);
    var arg = args_it.next(allocator);
    var i: usize = 0;
    while (arg != null) : (arg = args_it.next(allocator)) {
        i += 1;
        if (i == 1) continue;
        var a = try arg.?;
        accumulate = try std.mem.join(allocator, " ", &[_][]const u8{ accumulate, a });
    }
    return accumulate;
}

pub fn read_args(allocator: *std.mem.Allocator) anyerror![][]const u8 {
    return try tokenize(allocator, try read_args_str(allocator));
}

test "tokenize" {
    // e.g. treats [] brackets as individual tokens irregardless of whitespace
    // foo bar [baz]  => foo bar [ baz ]
    // foo bar [ baz] => foo bar [ baz ]

    {
        // e.g. treats [] brackets as individual tokens irregardless of whitespace
        var expect = [_][]const u8{ "foo", "bar", "[", "baz", "]" };
        var result = try tokenize("foo bar [baz]");
        try std.testing.expectEqual(@intCast(usize, 5), result.len);
        for (result) |_, idx| {
            try std.testing.expect(std.mem.eql(u8, expect[idx], result[idx]));
        }
    }

    {
        var expect = [_][]const u8{ "foo", "bar", "[", "baz", "]" };
        var result = try tokenize("foo bar [ baz]");
        try std.testing.expectEqual(@intCast(usize, 5), result.len);
        for (result) |_, idx| {
            try std.testing.expect(std.mem.eql(u8, expect[idx], result[idx]));
        }
    }
}

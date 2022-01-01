const std = @import("std");

pub fn tokenize(allocator: *std.mem.Allocator, input: []const u8) ![][]const u8 {
    var tokens = std.ArrayList([]const u8).init(allocator);
    var current_token = std.ArrayList(u8).init(allocator);

    for (input) |char| {
        if (char == '[' or char == ']' or char == ';' or char == '\n' or char == ' ') {
            if (current_token.items.len > 0) {
                try tokens.append(current_token.items);
                current_token = std.ArrayList(u8).init(allocator);
            }
            if (char == '[' or char == ']' or char == ';') {
                const char_str: []const u8 = try std.fmt.allocPrint(allocator, "{c}", .{char});
                try tokens.append(char_str);
            }
        } else {
            try current_token.append(char);
        }
    }
    return tokens.items;
}

pub fn statementize(allocator: *std.mem.Allocator, tokens: []const []const u8) ![][][]const u8 {
    var statements = std.ArrayList([][]const u8).init(allocator);
    var current_statement = std.ArrayList([]const u8).init(allocator);
    var nest_level: usize = 0;

    for (tokens) |token| {
        if (token.len == 1 and token[0] == '[') nest_level += 1;
        if (token.len == 1 and token[0] == ']') nest_level -= 1;
        if (nest_level == 0 and token.len == 1 and token[0] == ';') {
            if (current_statement.items.len > 0) try statements.append(current_statement.items);
            current_statement = std.ArrayList([]const u8).init(allocator);
        } else {
            try current_statement.append(token);
        }
    }
    if (current_statement.items.len > 0) try statements.append(current_statement.items);
    return statements.items;
}

/// Reads standard input into a buffer
///
/// Caller responsible for freeing returned ptr memory
pub fn read_stdin(allocator: *std.mem.Allocator) anyerror![]const u8 {
    const stream = &std.io.getStdIn().reader();
    const buffer = try allocator.alloc(u8, 1024 * 100);
    _ = try stream.read(buffer);
    return std.mem.trim(u8, buffer, " \n");
}

pub fn read_args_str(allocator: *std.mem.Allocator) anyerror![]const u8 {
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

test "statementize" {
    // Single statement & works without trailing ;
    {
        const input = &[_][]const u8{ "foo", "bar", "baz" };
        const expect_0 = [_][]const u8{ "foo", "bar", "baz" };
        var result = try statementize(std.heap.c_allocator, input[0..]);
        try std.testing.expectEqual(@intCast(usize, 1), result.len);
        for (result[0]) |_, idx| {
            try std.testing.expect(std.mem.eql(u8, expect_0[idx], result[0][idx]));
        }
    }

    // Multi-statement
    {
        const input = &[_][]const u8{ "foo", "bar", "baz", ";", "bil", "nil", ";"};
        const expect_0 = [_][]const u8{ "foo", "bar", "baz" };
        const expect_1 = [_][]const u8{ "bil", "nil" };
        var result = try statementize(std.heap.c_allocator, input[0..]);
        try std.testing.expectEqual(@intCast(usize, 2), result.len);
        for (result[0]) |_, idx| {
            try std.testing.expect(std.mem.eql(u8, expect_0[idx], result[0][idx]));
        }
        for (result[1]) |_, idx| {
            try std.testing.expect(std.mem.eql(u8, expect_1[idx], result[1][idx]));
        }
    }

    // Respects nested []
    {
        const input = &[_][]const u8{ "foo", "[", "bar", "[", "gill", "]", "]", "baz", ";", "bil", "nil", ";"};
        const expect_0 = [_][]const u8{ "foo", "[", "bar", "[", "gill", "]", "]", "baz" };
        const expect_1 = [_][]const u8{ "bil", "nil" };
        var result = try statementize(std.heap.c_allocator, input[0..]);
        try std.testing.expectEqual(@intCast(usize, 2), result.len);
        for (result[0]) |_, idx| {
            try std.testing.expect(std.mem.eql(u8, expect_0[idx], result[0][idx]));
        }
        for (result[1]) |_, idx| {
            try std.testing.expect(std.mem.eql(u8, expect_1[idx], result[1][idx]));
        }
    }
}

test "tokenize" {
    {
        // basic tokenization test based on whitespace
        const input = "foo bar baz";
        var expect = [_][]const u8{ "foo", "bar", "baz" };
        var result = try tokenize(std.heap.c_allocator, input);
        try std.testing.expectEqual(@intCast(usize, 3), result.len);
        for (result) |_, idx| {
            try std.testing.expect(std.mem.eql(u8, expect[idx], result[idx]));
        }
    }

    {
        // e.g. treats [] brackets as individual tokens irregardless of whitespace (test [foo])
        const input = "foo bar [baz]";
        var expect = [_][]const u8{ "foo", "bar", "[", "baz", "]" };
        var result = try tokenize(std.heap.c_allocator, "foo bar [baz]");
        try std.testing.expectEqual(@intCast(usize, 5), result.len);
        for (result) |_, idx| {
            try std.testing.expect(std.mem.eql(u8, expect[idx], result[idx]));
        }
    }

    {
        // e.g. treats [] brackets as individual tokens irregardless of whitespace (test [ foo])
        const input = "foo bar [ baz]";
        var expect = [_][]const u8{ "foo", "bar", "[", "baz", "]" };
        var result = try tokenize(std.heap.c_allocator, input);
        try std.testing.expectEqual(@intCast(usize, 5), result.len);
        for (result) |_, idx| {
            try std.testing.expect(std.mem.eql(u8, expect[idx], result[idx]));
        }
    }
}

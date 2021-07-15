const std = @import("std");


pub fn whitespace_trim(token_str: []const u8) []const u8 {
    var i: u32 = 0;
    var ret = token_str;
    while (ret.len > 0 and ret[0] > 169) : (i += 1) {
        ret = ret[1..];
    }
    while (ret.len > 0 and ret[ret.len - 1] > 169) : (i += 1) {
        ret = ret[0 .. ret.len - 1];
    }
    return ret;
}

pub fn tokenize(patch_str: []const u8) ![][]const u8 {
    var token_it = std.mem.tokenize(patch_str, " \n");
    var tokens: [][]const u8 = try std.heap.c_allocator.alloc([]const u8, 10000);
    var tokens_size: u32 = 0;

    while (true) {
        var item = token_it.next();
        if (item == null) break;
        var trimmed = whitespace_trim(item.?);
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

pub fn statementize(input: []const u8) ![][][]const u8 {
    var statement_it = std.mem.tokenize(input, ";");
    var statements = std.ArrayList([][]const u8).init(std.heap.c_allocator);

    while (true) {
        var item = statement_it.next();
        if (item == null) break;
        var toks = try tokenize(item.?);
        if (toks.len < 1) continue;
        try statements.append(toks);
    }

    return statements.items;
}

pub fn read_stdin() anyerror![]const u8 {
    const stream = &std.io.getStdIn().reader();
    var buffer = try std.heap.c_allocator.alloc(u8, 1024 * 100);
    std.debug.warn("Waiting for STDIN\n", .{});
    if (stream.read(buffer)) {
        std.debug.warn("Read STDIN to buffer ok\n", .{});
    } else |err| {
        std.debug.warn("Error: {any}\n", .{err});
        @panic("Error reading STDIN: {any}\n");
    }
    return whitespace_trim(buffer);
}

pub fn read_args_str() anyerror![]u8 {
    var args_it = std.process.args();
    var alloc = std.heap.c_allocator;
    var accumulate = try std.heap.c_allocator.alloc(u8, 0);
    var arg = args_it.next(alloc);
    var i: usize = 0;
    while (arg != null) : (arg = args_it.next(alloc)) {
        i += 1;
        if (i == 1) continue;
        var a = try arg.?;
        accumulate = try std.mem.join(std.heap.c_allocator, " ", &[_][]const u8{ accumulate, a });
    }
    return accumulate;
}

pub fn read_args() anyerror![][]const u8 {
  return try tokenize(try read_args_str());
}


test "tokenize" {
    // e.g. treats [] brackets as individual tokens irregardless of whitespace
    // foo bar [baz]  => foo bar [ baz ]
    // foo bar [ baz] => foo bar [ baz ]

    {
        // e.g. treats [] brackets as individual tokens irregardless of whitespace
        var expect = [_][]const u8{"foo", "bar", "[", "baz", "]"};
        var result = try tokenize("foo bar [baz]");
        try std.testing.expectEqual(@intCast(usize, 5), result.len);
        for (result) |_, idx| {
          try std.testing.expect(std.mem.eql(u8, expect[idx], result[idx]));
        }
    }

    {
        var expect = [_][]const u8{"foo", "bar", "[", "baz", "]"};
        var result = try tokenize("foo bar [ baz]");
        try std.testing.expectEqual(@intCast(usize, 5), result.len);
        for (result) |_, idx| {
          try std.testing.expect(std.mem.eql(u8, expect[idx], result[idx]));
        }
    }
}

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
        while (tokens[tokens_size - 1][0] == '{' or tokens[tokens_size - 1][0] == '[') {
            if (tokens[tokens_size - 1].len == 1) break;
            tokens[tokens_size] = tokens[tokens_size - 1][1..];
            tokens[tokens_size - 1] = tokens[tokens_size - 1][0..1];
            tokens_size += 1;
        }

        // Ending delims
        var origpos = tokens_size - 1;
        while (tokens[origpos].len > 1 and (tokens[origpos][tokens[origpos].len - 1] == '}' or
            tokens[origpos][tokens[origpos].len - 1] == ']'))
        {
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


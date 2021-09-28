const std = @import("std");

pub fn Lifo(comptime key_type: type, comptime metadata_type: type) type {
    return struct {
        array_hash_map: std.array_hash_map.AutoArrayHashMap(comptime key_type, comptime metadata_type),

        pub fn count(self: *@This()) usize  {
            return self.array_hash_map.count();
        }

        pub fn pop(self: *@This()) struct { key: key_type, value: metadata_type} {
            const popped = self.array_hash_map.pop();
            return .{ .key = popped.key, .value = popped.value };
        }

        pub fn getIndex(self: *@This(), key: key_type) ?usize {
            return self.array_hash_map.getIndex(key);
        }

        pub fn put(self: *@This(), k: key_type, v: metadata_type) !void {
            try self.array_hash_map.put(k, v);
        }

        pub fn clearAndFree(self: *@This()) void {
            self.array_hash_map.clearAndFree();
        }

        pub fn ensureCapacity(self: *@This(), size: usize) !void {
            try self.array_hash_map.ensureCapacity(size);
        }

        pub fn init(allocator: *std.mem.Allocator) @This() {
            return @as(@This(), .{
                .array_hash_map = std.array_hash_map.AutoArrayHashMap(key_type, metadata_type).init(allocator),
            });
        }
    };
}



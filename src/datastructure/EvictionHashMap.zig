const std = @import("std");

pub fn EvictionHashMap(comptime key_type: type, comptime metadata_type: type, size: usize) type {
    return struct {
        array_hash_map: std.array_hash_map.AutoArrayHashMap(comptime key_type, comptime metadata_type),
        size: usize,
        mutex: std.Thread.Mutex,

        pub fn count(self: *@This()) usize {
            const lock = self.mutex.acquire();
            defer lock.release();
            return self.array_hash_map.count();
        }

        pub fn get(self: *@This(), key: key_type) ?metadata_type {
            const lock = self.mutex.acquire();
            defer lock.release();
            return self.array_hash_map.get(key);
        }

        pub fn values(self: *@This()) []metadata_type {
            const lock = self.mutex.acquire();
            defer lock.release();
            return self.array_hash_map.values();
        }

        pub fn put(self: *@This(), k: key_type, v: metadata_type) !void {
            const lock = self.mutex.acquire();
            defer lock.release();
            try self.array_hash_map.put(k, v);
        }

        pub fn clearAndFree(self: *@This()) void {
            const lock = self.mutex.acquire();
            defer lock.release();
            self.array_hash_map.clearAndFree();
        }

        pub fn init(allocator: *std.mem.Allocator) @This() {
            return @as(@This(), .{
                .size = size,
                .mutex = std.Thread.Mutex{},
                .array_hash_map = std.array_hash_map.AutoArrayHashMap(key_type, metadata_type).init(allocator),
            });
        }
    };
}

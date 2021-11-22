const std = @import("std");

pub fn QueueHashMap(comptime key_type: type, comptime metadata_type: type) type {
    return struct {
        array_hash_map: std.array_hash_map.AutoArrayHashMap(comptime key_type, comptime metadata_type),
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

        pub fn pop(self: *@This()) struct { key: key_type, value: metadata_type } {
            const lock = self.mutex.acquire();
            defer lock.release();

            const popped = self.array_hash_map.pop();
            return .{ .key = popped.key, .value = popped.value };
        }

        pub fn getIndex(self: *@This(), key: key_type) ?usize {
            const lock = self.mutex.acquire();
            defer lock.release();

            return self.array_hash_map.getIndex(key);
        }

        pub fn swapRemove(self: *@This(), key: key_type) bool {
            const lock = self.mutex.acquire();
            defer lock.release();

            return self.array_hash_map.swapRemove(key);
        }

        pub fn values(self: *@This()) []metadata_type {
            const lock = self.mutex.acquire();
            defer lock.release();

            return self.array_hash_map.values();
        }

        pub fn iterator(self: *@This()) std.array_hash_map.AutoArrayHashMap(comptime key_type, comptime metadata_type).Iterator {
            const lock = self.mutex.acquire();
            defer lock.release();

            return self.array_hash_map.iterator();
        }

        pub fn put(self: *@This(), k: key_type, v: metadata_type) !void {
            const lock = self.mutex.acquire();
            defer lock.release();

            // E.g. ensures when putting items, we always reorder / bump
            // the most recently added item to the tail, thus makes lifo
            if (self.array_hash_map.contains(k)) {
                _ = self.array_hash_map.orderedRemove(k);
            }
            try self.array_hash_map.put(k, v);
        }

        pub fn clearAndFree(self: *@This()) void {
            const lock = self.mutex.acquire();
            defer lock.release();

            self.array_hash_map.clearAndFree();
        }

        pub fn init(allocator: *std.mem.Allocator) @This() {
            return @as(@This(), .{
                .mutex = std.Thread.Mutex{},
                .array_hash_map = std.array_hash_map.AutoArrayHashMap(key_type, metadata_type).init(allocator),
            });
        }
    };
}

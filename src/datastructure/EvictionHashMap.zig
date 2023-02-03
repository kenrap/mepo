const std = @import("std");

pub fn EvictionHashMap(comptime key_type: type, comptime metadata_type: type, comptime eviction_function: fn (key_type, metadata_type) void, comptime size: usize) type {
    return struct {
        array_hash_map: std.array_hash_map.AutoArrayHashMap(key_type, metadata_type),
        size: usize,
        mutex: std.Thread.Mutex,

        pub fn count(self: *@This()) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.array_hash_map.count();
        }

        pub fn get(self: *@This(), key: key_type) ?metadata_type {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.array_hash_map.get(key);
        }

        pub fn values(self: *@This()) []metadata_type {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.array_hash_map.values();
        }

        pub fn put(self: *@This(), k: key_type, v: metadata_type) !?metadata_type {
            self.mutex.lock();
            defer self.mutex.unlock();

            try self.array_hash_map.put(k, v);
            return if (self.array_hash_map.count() > self.size) return self.shift() else null;
        }

        fn shift(self: *@This()) !metadata_type {
            const shifted_key = self.array_hash_map.keys()[0];
            const shifted_val = self.array_hash_map.values()[0];
            self.array_hash_map.orderedRemoveAt(0);
            eviction_function(shifted_key, shifted_val);
            return shifted_val;
        }

        pub fn clearAndFree(self: *@This()) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            var it = self.array_hash_map.iterator();
            while (it.next()) |kv| eviction_function(kv.key_ptr.*, kv.value_ptr.*);
            self.array_hash_map.clearAndFree();
        }

        pub fn init(allocator: std.mem.Allocator) @This() {
            return @as(@This(), .{
                .size = size,
                .mutex = std.Thread.Mutex{},
                .array_hash_map = std.array_hash_map.AutoArrayHashMap(key_type, metadata_type).init(allocator),
            });
        }
    };
}

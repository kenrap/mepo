const std = @import("std");

pub fn EvictionHashMap(comptime key_type: type, comptime metadata_type: type, comptime eviction_function: fn (key_type, metadata_type) void, comptime size: *usize) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        array_hash_map: std.array_hash_map.Auto(key_type, metadata_type),
        size: *usize,
        io: std.Io,
        mutex: std.Io.Mutex,

        pub fn count(self: *Self) !usize {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);
            return self.array_hash_map.count();
        }

        pub fn get(self: *Self, key: key_type) !?metadata_type {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);
            return self.array_hash_map.get(key);
        }

        pub fn values(self: *Self) ![]metadata_type {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);
            return self.array_hash_map.values();
        }

        pub fn put(self: *Self, k: key_type, v: metadata_type) !?metadata_type {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);

            try self.array_hash_map.put(self.allocator, k, v);
            return if (self.array_hash_map.count() > self.size.*) return self.shift() else null;
        }

        fn shift(self: *Self) !metadata_type {
            const shifted_key = self.array_hash_map.keys()[0];
            const shifted_val = self.array_hash_map.values()[0];
            self.array_hash_map.orderedRemoveAt(0);
            eviction_function(shifted_key, shifted_val);
            return shifted_val;
        }

        pub fn clearAndFree(self: *Self) void {
            self.mutex.lock(self.io) catch @panic("Freeing, but failed to obtain lock");
            defer self.mutex.unlock(self.io);
            var it = self.array_hash_map.iterator();
            while (it.next()) |kv| eviction_function(kv.key_ptr.*, kv.value_ptr.*);
            self.array_hash_map.clearAndFree(self.allocator);
        }

        pub fn init(io: std.Io, allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .size = size,
                .io = io,
                .mutex = .init,
                .array_hash_map = .empty,
            };
        }
    };
}

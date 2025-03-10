const std = @import("std");

// QueueHashMap is essentially just a wrapper around zig's stdlib
// AutoArrayHashMap with two key differences:
//   1) All calls are wrapped around a mutex and thus all calls
//      for QueueHashMap are thread-safe
//   2) The put() function always bumps items to the tail of the
//      datastructure (irregardlesss of whether the item was already
//      present). This effectively allows usage as a LIFO since
//      running put() and then pop() ensures the same item is referenced
pub fn QueueHashMap(comptime key_type: type, comptime metadata_type: type) type {
    return struct {
        const Self = @This();
        array_hash_map: std.array_hash_map.AutoArrayHashMap(key_type, metadata_type),
        mutex: std.Thread.Mutex,

        pub fn count(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.array_hash_map.count();
        }

        pub fn get(self: *Self, key: key_type) ?metadata_type {
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.array_hash_map.get(key);
        }

        pub fn getPtr(self: *Self, key: key_type) ?*metadata_type {
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.array_hash_map.getPtr(key);
        }

        pub fn pop(self: *Self) ?struct { key: key_type, value: metadata_type } {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.array_hash_map.pop()) |popped| {
                return .{ .key = popped.key, .value = popped.value };
            }
            return null;
        }

        pub fn getIndex(self: *Self, key: key_type) ?usize {
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.array_hash_map.getIndex(key);
        }

        pub fn swapRemove(self: *Self, key: key_type) bool {
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.array_hash_map.swapRemove(key);
        }

        pub fn values(self: *Self) []metadata_type {
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.array_hash_map.values();
        }

        pub fn iterator(self: *Self) std.array_hash_map.AutoArrayHashMap(key_type, metadata_type).Iterator {
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.array_hash_map.iterator();
        }

        pub fn put(self: *Self, k: key_type, v: metadata_type) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            // E.g. ensures when putting items, we always reorder / bump
            // the most recently added item to the tail, thus makes lifo
            if (self.array_hash_map.contains(k)) {
                _ = self.array_hash_map.orderedRemove(k);
            }
            try self.array_hash_map.put(k, v);
        }

        pub fn clearAndFree(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.array_hash_map.clearAndFree();
        }

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .mutex = std.Thread.Mutex{},
                .array_hash_map = std.array_hash_map.AutoArrayHashMap(key_type, metadata_type).init(allocator),
            };
        }
    };
}

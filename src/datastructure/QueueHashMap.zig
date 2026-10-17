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
        allocator: std.mem.Allocator,
        array_hash_map: std.array_hash_map.Auto(key_type, metadata_type),
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

        pub fn getPtr(self: *Self, key: key_type) !?*metadata_type {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);

            return self.array_hash_map.getPtr(key);
        }

        pub fn pop(self: *Self) !?struct { key: key_type, value: metadata_type } {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);

            if (self.array_hash_map.pop()) |popped| {
                return .{ .key = popped.key, .value = popped.value };
            }
            return null;
        }

        pub fn getIndex(self: *Self, key: key_type) !?usize {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);

            return self.array_hash_map.getIndex(key);
        }

        pub fn swapRemove(self: *Self, key: key_type) !bool {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);

            return self.array_hash_map.swapRemove(key);
        }

        pub fn values(self: *Self) ![]metadata_type {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);

            return self.array_hash_map.values();
        }

        pub fn iterator(self: *Self) !std.array_hash_map.Auto(key_type, metadata_type).Iterator {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);

            return self.array_hash_map.iterator();
        }

        /// For a QueueHashMap with void metadata type, pass `null`. For a non-void
        /// metadata type the param is not optional, so passing null there is a
        /// compile-time error.
        pub fn put(self: *Self, k: key_type, v: if (metadata_type == void) ?metadata_type else metadata_type) !void {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);

            // E.g. ensures when putting items, we always reorder / bump
            // the most recently added item to the tail, thus makes lifo
            if (self.array_hash_map.contains(k)) {
                _ = self.array_hash_map.orderedRemove(k);
            }
            if (metadata_type == void) {
                _ = try self.array_hash_map.getOrPut(self.allocator, k);
            } else {
                try self.array_hash_map.put(self.allocator, k, v);
            }
        }

        pub fn clearAndFree(self: *Self) void {
            self.mutex.lock(self.io) catch @panic("Freeing, but failed to obtain lock");
            defer self.mutex.unlock(self.io);

            self.array_hash_map.clearAndFree(self.allocator);
        }

        pub fn init(io: std.Io, allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .io = io,
                .mutex = .init,
                .array_hash_map = .empty,
            };
        }
    };
}

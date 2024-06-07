const std = @import("std");

const ComparisonValue = union(enum) {
    String: []const u8,
    Number: u64,
};

fn Moeban(comptime S: type, comptime T: type) type {
    return struct {
        db_name: []const u8,
        allocator: std.mem.Allocator,

        fn init(db_name: []const u8, default_data: []const u8, allocator: std.mem.Allocator) !Moeban(S, T) {
            if (!try existsDataBase(db_name)) _ = try createDataBase(db_name, default_data);
            return .{ .db_name = db_name, .allocator = allocator };
        }

        fn existsDataBase(db_name: []const u8) !bool {
            std.fs.cwd().access(db_name, .{ .mode = .read_only }) catch |err| {
                if (err == error.FileNotFound) {
                    return false;
                }
            };
            return true;
        }

        fn createDataBase(db_name: []const u8, default_data: []const u8) !bool {
            var file: std.fs.File = undefined;

            if (std.fs.cwd().createFile(db_name, .{})) |craatedFile| {
                file = craatedFile;
                defer file.close();

                file.writeAll(default_data) catch |err| {
                    if (err == error.AccessDenied) {
                        return false;
                    }

                    return error.WriteError;
                };

                return true;
            } else |err| {
                if (err == error.FileNotFound) {
                    return false;
                }
                return error.FileCreationError;
            }
        }

        fn readDataBase(this: @This(), db_name: []const u8) ![]const u8 {
            const file = std.fs.cwd().readFileAlloc(this.allocator, db_name, std.math.maxInt(usize)) catch |err| {
                return err;
            };

            return file;
        }

        fn parser(this: @This(), db_name: []const u8) !struct { jsonData: []const u8, parsedData: std.json.Parsed(S) } {
            const jsonData = try this.readDataBase(db_name);
            const parsedData = try std.json.parseFromSlice(S, this.allocator, jsonData, .{});
            return .{ .jsonData = jsonData, .parsedData = parsedData };
        }

        fn compareById(_: @TypeOf(.{}), lhs: T, rhs: T) bool {
            return lhs.id < rhs.id;
        }

        pub fn findById(this: @This(), comptime field: []const u8, id: u64) !struct { item: T, index: u64, data: []const u8 } {
            const arr_parsed = try this.parser(this.db_name);
            defer arr_parsed.parsedData.deinit();

            const items = @field(arr_parsed.parsedData.value, field);

            if (items.len == 0) {
                defer this.allocator.free(arr_parsed.jsonData);
                return error.ItemNotFound;
            }

            std.mem.sort(T, items, .{}, compareById);

            var left: usize = 0;
            var right: usize = items.len;

            while (left < right) {
                const mid = left + (right - left) / 2;
                const item = items[mid];

                if (item.id == id) {
                    return .{ .item = item, .index = mid, .data = arr_parsed.jsonData };
                } else if (item.id < id) {
                    left = mid + 1;
                } else {
                    right = mid;
                }
            }

            defer this.allocator.free(arr_parsed.jsonData);

            return error.ItemNotFound;
        }

        pub fn write(this: @This(), comptime field: []const u8, item: T) !void {
            const arr_parsed = try this.parser(this.db_name);
            defer arr_parsed.parsedData.deinit();

            defer this.allocator.free(arr_parsed.jsonData);

            const items = @field(arr_parsed.parsedData.value, field);

            var arr = std.ArrayList(T).init(this.allocator);
            defer arr.deinit();

            try arr.resize(items.len);

            @memcpy(arr.items, items);

            try arr.append(item);

            const dbFile = try std.fs.cwd().openFile(this.db_name, .{});
            defer dbFile.close();

            const dbContentStr = try dbFile.readToEndAlloc(this.allocator, std.math.maxInt(usize));
            defer this.allocator.free(dbContentStr);

            var newObjectContent = try std.json.parseFromSlice(S, this.allocator, dbContentStr, .{});
            defer newObjectContent.deinit();

            std.mem.sort(T, arr.items, .{}, compareById);

            @field(newObjectContent.value, field) = arr.items;

            const serializedDbContent = try std.json.stringifyAlloc(this.allocator, newObjectContent.value, .{});
            defer this.allocator.free(serializedDbContent);

            const updatedDataBase = try std.fs.cwd().openFile(this.db_name, .{ .mode = .read_write });
            defer updatedDataBase.close();

            try updatedDataBase.setEndPos(0);
            try updatedDataBase.writeAll(serializedDbContent);
        }

        fn writeMany(this: @This(), comptime field: []const u8, items: []T) !void {
            const arr_parsed = try this.parser(this.db_name);
            defer arr_parsed.parsedData.deinit();

            defer this.allocator.free(arr_parsed.jsonData);

            const existing_items = @field(arr_parsed.parsedData.value, field);

            var arr = std.ArrayList(T).init(this.allocator);
            defer arr.deinit();
            try arr.appendSlice(existing_items);
            try arr.appendSlice(items);

            const dbFile = try std.fs.cwd().openFile(this.db_name, .{});
            defer dbFile.close();

            const dbContentStr = try dbFile.readToEndAlloc(this.allocator, std.math.maxInt(usize));
            defer this.allocator.free(dbContentStr);

            var newObjectContent = try std.json.parseFromSlice(S, this.allocator, dbContentStr, .{});
            defer newObjectContent.deinit();

            std.mem.sort(T, arr.items, .{}, compareById);

            @field(newObjectContent.value, field) = arr.items;

            const serializedDbContent = try std.json.stringifyAlloc(this.allocator, newObjectContent.value, .{});
            defer this.allocator.free(serializedDbContent);

            const updatedDataBase = try std.fs.cwd().openFile(this.db_name, .{ .mode = .read_write });
            defer updatedDataBase.close();

            try updatedDataBase.setEndPos(0);
            try updatedDataBase.writeAll(serializedDbContent);
        }

        pub fn deleteOne(this: @This(), comptime field: []const u8, id: u64) !void {
            const result = this.findById(field, id);
            if (result) |itemData| {
                this.allocator.free(itemData.data);
                const arr_parsed = try this.parser(this.db_name);
                defer arr_parsed.parsedData.deinit();

                defer this.allocator.free(arr_parsed.jsonData);

                const items = @field(arr_parsed.parsedData.value, field);

                if (items.len == 0) {
                    return error.ItemNotFound;
                }

                var arr = std.ArrayList(T).init(this.allocator);
                defer arr.deinit();

                try arr.resize(items.len);

                @memcpy(arr.items, items);

                std.mem.sort(T, arr.items, .{}, compareById);

                _ = arr.swapRemove(@intCast(itemData.index));

                const dbFile = try std.fs.cwd().openFile(this.db_name, .{});
                defer dbFile.close();

                const dbContentStr = try dbFile.readToEndAlloc(this.allocator, std.math.maxInt(usize));
                defer this.allocator.free(dbContentStr);

                var newObjectContent = try std.json.parseFromSlice(S, this.allocator, dbContentStr, .{});
                defer newObjectContent.deinit();

                std.mem.sort(T, arr.items, .{}, compareById);

                @field(newObjectContent.value, field) = arr.items;

                const serializedDbContent = try std.json.stringifyAlloc(this.allocator, newObjectContent.value, .{});
                defer this.allocator.free(serializedDbContent);

                const updatedDataBase = try std.fs.cwd().openFile(this.db_name, .{ .mode = .write_only });
                defer updatedDataBase.close();

                try updatedDataBase.setEndPos(0);
                try updatedDataBase.writeAll(serializedDbContent);
            } else |err| {
                return err;
            }
        }

        pub fn deleteMany(this: @This(), comptime field: []const u8, comptime property: []const u8, comptime value: ComparisonValue) !void {
            const arr_parsed = try this.parser(this.db_name);
            defer arr_parsed.parsedData.deinit();
            defer this.allocator.free(arr_parsed.jsonData);

            const items = @field(arr_parsed.parsedData.value, field);
            if (items.len == 0) {
                return error.ItemNotFound;
            }

            var arr = std.ArrayList(T).init(this.allocator);
            defer arr.deinit();

            const item_chunks: u32 = 4;
            const chunk_size = items.len / item_chunks;

            for (0..item_chunks) |chunk_idx| {
                const start_idx = chunk_idx * chunk_size;
                const end_idx = if (chunk_idx == item_chunks - 1) items.len else start_idx + chunk_size;

                for (start_idx..end_idx) |i| {
                    const item = items[i];
                    const val = @field(item, property);
                    switch (value) {
                        .String => |num| {
                            if (!std.mem.eql(u8, val, num)) try arr.append(item);
                        },
                        .Number => |num| {
                            if (val != num) try arr.append(item);
                        },
                    }
                }
            }

            const dbFile = try std.fs.cwd().openFile(this.db_name, .{});
            defer dbFile.close();

            const dbContentStr = try dbFile.readToEndAlloc(this.allocator, std.math.maxInt(usize));
            defer this.allocator.free(dbContentStr);

            var newObjectContent = try std.json.parseFromSlice(S, this.allocator, dbContentStr, .{});
            defer newObjectContent.deinit();

            @field(newObjectContent.value, field) = arr.items;

            const serializedDbContent = try std.json.stringifyAlloc(this.allocator, newObjectContent.value, .{});
            defer this.allocator.free(serializedDbContent);

            const updatedDataBase = try std.fs.cwd().openFile(this.db_name, .{ .mode = .read_write });
            defer updatedDataBase.close();

            try updatedDataBase.setEndPos(0);
            try updatedDataBase.writeAll(serializedDbContent);
        }
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const allocator_status = gpa.deinit();

        if (allocator_status == .leak) {
            std.debug.print("Leak\n", .{});
        }
    }

    const User = struct { id: u64, name: []const u8, age: u64 };

    const Schema = struct { items: []User, others: []User };

    const default_data =
        \\{ "items": [], "others": [] }
    ;

    const startTime = std.time.milliTimestamp();

    const moeban = try Moeban(Schema, User).init("test.json", default_data, allocator);

    try moeban.write("items", .{ .id = 1, .name = "sam", .age = 22 });

    const user = try moeban.findById("items", 1);
    defer allocator.free(user.data);
    std.debug.print("{}\n", .{user.item});

    try moeban.deleteOne("items", 1);

    var users = std.ArrayList(User).init(allocator);
    defer users.deinit();
    while (users.items.len < 100) {
        const usr = User{ .id = @intCast(users.items.len + 1), .name = "lucas", .age = 22 };
        try users.append(usr);
    }

    try moeban.writeMany("others", users.items);
    try moeban.deleteMany("others", "age", .{ .Number = 22 });
    defer std.debug.print("Program executed in: {d} s\n", .{@divTrunc(std.time.milliTimestamp() - startTime, 1000)});
}

const std = @import("std");

const User = struct {
    id: u64,
    age: u64,
};

const Schema = struct {
    a: []User,
    b: []User,
};

// S = SCHEMA
// T = Type User

fn Moeban(comptime S: type, comptime T: type) type {
    return struct {
        db_name: []const u8,
        allocator: std.mem.Allocator,

        fn init(db_name: []const u8, default_data: []const u8, allocator: std.mem.Allocator) !Moeban(S, T) {
            if (!try existsDataBase(db_name)) _ = try createDataBase(db_name, default_data);
            return .{ .db_name = db_name, .allocator = allocator };
        }

        // fn moebanAllocator(allocator: std.mem.Allocator) std.mem.Allocator {
        //     var arena = std.heap.ArenaAllocator.init(allocator);
        //     defer arena.deinit();

        //     // const arenaAllocator = arena.allocator();
        //     return arena.allocator();
        // }

        // fn deinit() void {}

        // fn existsDataBase(_:@This(), db_name: []const u8) !bool {
        //     std.fs.cwd().access(db_name, .{ .mode = .read_only }) catch |err| {
        //         if (err == error.FileNotFound) {
        //             return false;
        //         }
        //     };
        //     return true;
        // }

        fn existsDataBase(db_name: []const u8) !bool {
            std.fs.cwd().access(db_name, .{ .mode = .read_only }) catch |err| {
                if (err == error.FileNotFound) {
                    return false;
                }
            };
            return true;
        }

        // fn createDataBase(_: @this(), db_name: []const u8, default_data: []const u8) !bool {
        //     var file: std.fs.File = undefined;
        //     if (std.fs.cwd().createFile(db_name, .{})) |createdFile| {
        //         file = createdFile;
        //         defer file.close();

        //         file.writeAll(default_data) catch |err| {
        //             // std.debug.print("Err {}", .{err});
        //             if (err == error.AccessDenied) {
        //                 return false;
        //             }
        //             return error.WriteError;
        //         };

        //         return true;
        //     } else |err| {
        //         // std.debug.print("Err {}", .{err});
        //         if (err == error.FileNotFound) {
        //             return false;
        //         }
        //         return error.FileCreationError;
        //     }
        // }

        fn createDataBase(db_name: []const u8, default_data: []const u8) !bool {
            var file: std.fs.File = undefined;
            if (std.fs.cwd().createFile(db_name, .{})) |createdFile| {
                file = createdFile;
                defer file.close();

                file.writeAll(default_data) catch |err| {
                    // std.debug.print("Err {}", .{err});
                    if (err == error.AccessDenied) {
                        return false;
                    }
                    return error.WriteError;
                };

                return true;
            } else |err| {
                // std.debug.print("Err {}", .{err});
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

        // fn compareById(_: @This(), lhs: T, rhs: T) bool {
        //     return lhs.id < rhs.id;
        // }

        fn compareById(_: @TypeOf(.{}), lhs: T, rhs: T) bool {
            return lhs.id < rhs.id;
        }

        fn parser(this: @This(), db_name: []const u8) !S {
            const jsonData = try this.readDataBase(db_name);
            const parsedData = try std.json.parseFromSlice(S, this.allocator, jsonData, .{});
            return parsedData.value;
        }

        fn findById(this: @This(), comptime field: []const u8, id: u64) !T {
            const arr_parsed = try this.parser(this.db_name);
            const items = @field(arr_parsed, field);

            if (items.len == 0) return error.ItemNotFound;

            std.mem.sort(T, items, .{}, compareById);

            var left: usize = 0;
            var right: usize = items.len;

            while (left < right) {
                const mid = left + (right - left) / 2;
                const item = items[mid];

                if (item.id == id) {
                    return item;
                } else if (item.id < id) {
                    left = mid + 1;
                } else {
                    right = mid;
                }
            }

            return error.ItemNotFound;
        }

        pub fn write(this: @This(), comptime field: []const u8, item: T) !void {
            const arr_parsed = try this.parser(this.db_name);

            const items = @field(arr_parsed, field);

            var arr = std.ArrayList(T).init(this.allocator);
            defer arr.deinit();

            try arr.resize(items.len);

            @memcpy(arr.items, items);

            try arr.append(item);

            const jsonData = try std.json.stringifyAlloc(this.allocator, arr.items, .{});
            defer this.allocator.free(jsonData);

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

            try updatedDataBase.writeAll(serializedDbContent);

            // std.debug.print("{s}\n", .{jsonData});
        }
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();

        if (deinit_status == .leak) {
            std.debug.print("Memory leak \n", .{});
        }
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const arenaAllocator = arena.allocator();

    const data_base = "db_test.json";
    const default_data =
        \\{
        \\  "a":[],
        \\  "b":[] 
        \\}
    ;

    const moeban = try Moeban(Schema, User).init(data_base, default_data, arenaAllocator);

    const newUser = User{ .id = 1, .age = 22 };
    try moeban.write("a", newUser);

    const user = try moeban.findById("a", 1);
    std.debug.print("{}\n", .{user});
}

test "MOEBAN" {
    // const allocator = std.heap.page_allocator;

    // const data_base = "db_test.json";
    // const default_data =
    // \\{
    // \\  "a":[],
    // \\  "b":[]
    // \\}
    // ;

    // const moeban = Moeban(Schema, User).init(data_base, default_data, allocator);

    // const database_created = try moeban.createDataBase(data_base, default_data);
    // const database_not_created = try moeban.createDataBase("/random_dir/data_test.json", default_data);

    // const db_exist = try moeban.existsDataBase(data_base);
    // const db_not_exist = try moeban.existsDataBase("db_not_exist.json");

    // const file_content = try moeban.readDataBase(data_base);
    // defer allocator.free(file_content);

    // const userA = User{ .id = 1, .age = 21 };
    // const userB = User{ .id = 2, .age = 22 };
    // const compare_a_w_b = moeban.compareById(userA, userB);

    // try std.testing.expect(database_created == true);
    // try std.testing.expect(database_not_created == false);

    // try std.testing.expect(db_exist == true);
    // try std.testing.expect(db_not_exist == false);

    // try std.testing.expect(compare_a_w_b == true);

    // try std.testing.expectEqualStrings(file_content, default_data);
}

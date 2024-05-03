const std = @import("std");
const User = struct { id: u64, age: u64 };

const Schema = struct { a: []User, b: []User };

fn Moeban(comptime T: type) type {
    return struct {
        db_name: []const u8,
        default_data: []const u8,
        comptime schema: type = T,

        fn init(db_name: []const u8, default_data: []const u8) Moeban(T) {
            return .{ .db_name = db_name, .default_data = default_data };
        }

        pub fn existsDataBase(_: @This(), db_name: []const u8) !bool {
            std.fs.cwd().access(db_name, .{ .mode = .read_only }) catch |err| {
                if (err == error.FileNotFound) {
                    return false;
                }
            };
            return true;
        }

        pub fn createDataBase(_: @This(), db_name: []const u8, db_content: []const u8) !void {
            const file = std.fs.cwd().createFile(db_name, .{}) catch |err| {
                std.debug.print("Could not create dababase Err:{}\n", .{err});
                return;
            };
            defer file.close();

            file.writeAll(db_content) catch |err| {
                std.debug.print("Could not write to de database Err: {}\n", .{err});
            };

            std.debug.print("Database \"{s}\" was created\n", .{db_name});
        }

        pub fn readDataBase(db_name: []const u8, allocator: std.mem.Allocator) ![]const u8 {
            const file = std.fs.cwd().readFileAlloc(allocator, db_name, std.math.maxInt(usize)) catch |err| {
                std.debug.print("Could not read database {}\n", .{err});
                return err;
            };
            return file;
        }

        pub fn stringify(allocator: std.mem.Allocator, value: std.json.Value) !T {
            const str = try std.json.stringifyAlloc(allocator, value, .{ .whitespace = .indent_2 });
            return str;
        }

        pub fn parser(_: @This(), db_name: []const u8, allocator: std.mem.Allocator) !T {
            const jsonData = try readDataBase(db_name, allocator);
            // defer allocator.free(jsonData);
            const parsedData = try std.json.parseFromSlice(T, allocator, jsonData, .{});
            return parsedData.value;
        }
    };
}

fn Model(comptime T: type, comptime MoebanType: type) type {
    return struct {
        moeban: MoebanType,
        allocator: std.mem.Allocator,

        fn init(moeban: MoebanType, allocator: std.mem.Allocator) !Model(T, MoebanType) {
            if (!try moeban.existsDataBase(moeban.db_name)) try moeban.createDataBase(moeban.db_name, moeban.default_data);
            return .{ .moeban = moeban, .allocator = allocator };
        }

        fn compareById(_: @TypeOf(.{}), lhs: T, rhs: T) bool {
            return lhs.id < rhs.id;
        }

        pub fn findById(this: @This(), comptime field: []const u8, id: u64) !T {
            const arr_parsed = try this.moeban.parser(this.moeban.db_name, this.allocator);

            const items = @field(arr_parsed, field);

            if (items.len == 0) {
                return error.ItemNotFound;
            }

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

        pub fn write(this: @This(), comptime schema: type, comptime field: []const u8, item: T) !void {
            const arr_parsed = try this.moeban.parser(this.moeban.db_name, this.allocator);

            const items = @field(arr_parsed, field);

            var arr = std.ArrayList(T).init(this.allocator);
            defer arr.deinit();

            try arr.resize(items.len);

            @memcpy(arr.items, items);

            try arr.append(item);

            const jsonData = try std.json.stringifyAlloc(this.allocator, arr.items, .{});
            defer this.allocator.free(jsonData);

            const dbFile = try std.fs.cwd().openFile(this.moeban.db_name, .{});
            defer dbFile.close();

            const dbContentStr = try dbFile.readToEndAlloc(this.allocator, std.math.maxInt(usize));
            defer this.allocator.free(dbContentStr);

            var newObjectContent = try std.json.parseFromSlice(schema, this.allocator, dbContentStr, .{});
            defer newObjectContent.deinit();

            @field(newObjectContent.value, field) = arr.items;

            const serializedDbContent = try std.json.stringifyAlloc(this.allocator, newObjectContent.value, .{});
            defer this.allocator.free(serializedDbContent);

            const updatedDataBase = try std.fs.cwd().openFile(this.moeban.db_name, .{ .mode = .read_write });
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
            std.debug.print("memory leak \n", .{});
        }
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const arenaAllocator = arena.allocator();

    const default_data =
        \\ {
        \\     "a":[],
        \\     "b":[]
        \\ }
    ;

    const MoebanSchema = Moeban(Schema);
    const moeban = MoebanSchema.init("db_test.json", default_data);
    const model = try Model(User, MoebanSchema).init(moeban, arenaAllocator);

    const item = User{ .id = 2, .age = 22 };
    try model.write(Schema, "b", item);

    const id = try model.findById("a", 2);
    std.debug.print("{}\n", .{id});

    // _ = model;
}

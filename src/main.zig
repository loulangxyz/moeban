const std = @import("std");

fn Moeban(comptime T: type) type {
    return struct {
        db_name: []const u8,
        default_data: []const u8,
        db_content: T,
        allocator: std.mem.Allocator,

        fn init(db_name: []const u8, defultData: []const u8, allocator: std.mem.Allocator) !Moeban(T) {
            if (try existsDataBase(db_name)) {
                return .{
                    .db_name = db_name,
                    .default_data = defultData,
                    .db_content = try parser(db_name, allocator),
                    .allocator = allocator,
                };
            } else {
                try createDataBase(db_name, defultData);
                return .{
                    .db_name = db_name,
                    .default_data = defultData,
                    .db_content = try parser(db_name, allocator),
                    .allocator = allocator,
                };
            }
            return error.NoSePudoIntanciar;
        }

        fn deinit(this: @This()) void {
            this.allocator.free(this.db_content);
        }

        pub fn existsDataBase(db_name: []const u8) !bool {
            std.fs.cwd().access(db_name, .{ .mode = .read_only }) catch |err| {
                if (err == error.FileNotFound) {
                    return false;
                }
            };
            return true;
        }

        pub fn createDataBase(db_name: []const u8, db_content: []const u8) !void {
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

        fn readDataBase(db_name: []const u8, allocator: std.mem.Allocator) ![]const u8 {
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

        fn parser(db_name: []const u8, allocator: std.mem.Allocator) !T {
            const jsonData = try readDataBase(db_name, allocator);
            // defer allocator.free(jsonData);
            const parsedData = try std.json.parseFromSlice(T, allocator, jsonData, .{});
            return parsedData.value;
        }
    };
}

fn Model(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        fn init(allocator: std.mem.Allocator) !Model(T) {
            return .{ .allocator = allocator };
        }

        fn compareById(context: @TypeOf(.{}), lhs: T, rhs: T) bool {
            _ = context;
            return lhs.id < rhs.id;
        }

        pub fn findById(this: @This(), items: []T, id: u64) !T {
            _ = this;

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

        // // Función para agregar un nuevo usuario al array de manera ordenada
        // pub fn addUser(this: @This(), items: []T, newUser: T) !void {
        //     _ = this;

        //     // Encuentra la posición donde insertar el nuevo usuario para mantener el orden
        //     var pos: usize = 0;
        //     while (pos < items.len and items[pos].id < newUser.id) {
        //         pos += 1;
        //     }

        //     // Inserta el nuevo usuario en la posición encontrada
        //     try items.insert(pos, newUser);
        // }
    };
}

const User = struct {
    id: u64,
    age: u64,
    name: []const u8,
};

const Schema = struct { tarde: []User, noche: []User };

const json_str =
    \\ {
    \\     "tarde":[],
    \\     "noche":[]
    \\ }
;

fn insertUser(allocator: std.mem.Allocator, items: []User, newUser: User) !void {
    var arr = std.ArrayList(User).init(allocator);
    defer arr.deinit();
    try arr.resize(items.len);

    @memcpy(arr.items, items);

    try arr.append(newUser);

    const jsonData = try std.json.stringifyAlloc(allocator, arr.items, .{});
    defer allocator.free(jsonData);

    const dbFile = try std.fs.cwd().openFile("db_test.json", .{});
    defer dbFile.close();

    const dbContentStr = try dbFile.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(dbContentStr);
    // std.debug.print("{s}\n", .{dbContentStr});

    var newObjectContent = try std.json.parseFromSlice(Schema, allocator, dbContentStr, .{});
    defer newObjectContent.deinit();

    @field(newObjectContent.value, "tarde") = arr.items;

    // std.debug.print("{any}\n", .{newObjectContent.value});

    const serializedDbContent = try std.json.stringifyAlloc(allocator, newObjectContent.value, .{});
    defer allocator.free(serializedDbContent);

    // std.debug.print("{s}\n", .{serializedDbContent});

    const updatedDataBase = try std.fs.cwd().openFile("db_test.json", .{ .mode = .read_write });
    defer updatedDataBase.close();

    try updatedDataBase.writeAll(serializedDbContent);
}

pub fn main() !void {
    // const allocator = std.heap.page_allocator;

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

    const db = try Moeban(Schema).init("db_test.json", json_str, arenaAllocator);
    const model = try Model(User).init(arenaAllocator);

    _ = model;

    // const user = try model.findById(db.db_content.tarde, 1);
    // std.debug.print("{}\n", .{user});

    const newUser = User{ .id = 3, .age = 34, .name = "lucas" };

    try insertUser(allocator, db.db_content.tarde, newUser);
}

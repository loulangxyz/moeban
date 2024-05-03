const std = @import("std");

const User = struct { id: u64, age: u64 };

const Schema = struct { tarde: []User, noche: []User };

fn Moeban(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        mainType: type = T,

        fn init(allocator: std.mem.Allocator) !@This() {
            return .{ .allocator = allocator };
        }

        fn some(self: @This()) void {
            std.debug.print("{}\n", .{self.mainType});
        }
    };
}

fn Model(comptime T: type) type {
    return struct {
        moeban: Moeban(T),

        pub fn init(moebanInstance: Moeban(T)) @This() {
            return .{ .moeban = moebanInstance };
        }

        pub fn someFunctionInModel(self: @This()) void {
            std.debug.print("HERE {}\n", .{self.moeban.mainType});
        }
    };
}

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();

    // defer {
    //     const deinit_status = gpa.deinit();
    //     if (deinit_status == .leak) {
    //         std.debug.print("memory leak \n", .{});
    //     }
    // }

    // var arena = std.heap.ArenaAllocator.init(allocator);
    // defer arena.deinit();

    // const arenaAllocator = arena.allocator();

    const allocator = std.heap.page_allocator;
    // Instancia Moeban con Schema
    // const moebanSchema = try Moeban(Schema).init(allocator);
    // Instancia Moeban con User
    const moebanUser = try Moeban(User).init(allocator);
    // Instancia Model con User y pasa la instancia de Moeban como parámetro
    const model = Model(User).init(moebanUser);
    _ = model;
}

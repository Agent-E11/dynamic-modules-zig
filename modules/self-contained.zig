//! A module that handles it's own state, ignoring the context passed to it.

const State = struct {
    num: u32,
};
var state = State{ .num = 0 };

const std = @import("std");

pub const name = "self-contained";

pub fn init(_: std.mem.Allocator, _: *?*anyopaque) anyerror!void {}

pub fn display(allocator: std.mem.Allocator, _: ?*anyopaque) anyerror![]const u8 {
    return std.fmt.allocPrint(allocator, "{}", .{state.num});
}

pub fn process(_: std.mem.Allocator, _: ?*anyopaque, input: []const u8) anyerror!void {
    state.num = try std.fmt.parseInt(u32, input, 10);
}

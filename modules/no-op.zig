//! Declare all needed methods but don't do anything inside of them.

const std = @import("std");

pub const name = "no-op";

pub fn init(_: std.mem.Allocator, _: *?*anyopaque) anyerror!void {}

pub fn display(_: std.mem.Allocator, _: ?*anyopaque) anyerror![]const u8 {
    return "";
}

pub fn process(_: std.mem.Allocator, _: ?*anyopaque, _: []const u8) anyerror!void {}

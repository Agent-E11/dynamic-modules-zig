//! Copy the input into the state

const std = @import("std");
const print = std.debug.print;

pub const name = "copy";

const State = struct {
    msg: []const u8,
};

var state: State = undefined;

pub fn init(_: std.mem.Allocator, _: *?*anyopaque) anyerror!void { // NOTE: The error type cannot be inferred, because wrapper.Mod expects an anyerror set
    state = State{ .msg = "" };
}

pub fn display(_: std.mem.Allocator, _: ?*anyopaque) anyerror![]const u8 {
    return state.msg;
}

pub fn process(_: std.mem.Allocator, _: ?*anyopaque, input: []const u8) anyerror!void {
    state.msg = input;
}

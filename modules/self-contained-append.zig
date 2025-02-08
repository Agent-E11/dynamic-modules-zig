//! Append the input to the state

const std = @import("std");
const print = std.debug.print;
const String = std.ArrayList(u8);

pub const name = "self-contained-append";

const State = struct {
    msg: String,
};

var state: State = undefined;

/// Initialize the module's internal state
///
/// IMPORTANT: This function _must_ be called before calling any other
/// of this module's functions
pub fn init(allocator: std.mem.Allocator, _: *?*anyopaque) anyerror!void { // NOTE: The error type cannot be inferred, because wrapper.Mod expects an anyerror set
    state = State{
        .msg = String.init(allocator),
    };
}

pub fn display(_: std.mem.Allocator, _: ?*anyopaque) anyerror![]const u8 {
    return state.msg.items;
}

pub fn process(_: std.mem.Allocator, _: ?*anyopaque, input: []const u8) anyerror!void {
    return state.msg.appendSlice(input);
}

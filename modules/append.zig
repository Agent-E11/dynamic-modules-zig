//! Append the input to the state

const std = @import("std");
const print = std.debug.print;
const String = std.ArrayList(u8);

pub const name = "append";

const State = struct {
    msg: String,
};

pub fn init(allocator: std.mem.Allocator, context_ptr: *?*anyopaque) anyerror!void { // NOTE: The error type cannot be inferred, because wrapper.Mod expects an anyerror set
    if (context_ptr.* == null) {
        context_ptr.* = try allocator.create(State);
        const state: *State = @ptrCast(@alignCast(context_ptr.*));

        state.* = State{
            .msg = String.init(allocator),
        };
    }
}

pub fn display(allocator: std.mem.Allocator, context: ?*anyopaque) anyerror![]const u8 {
    _ = allocator;

    const state: *State = @ptrCast(@alignCast(
        context orelse return error.NullContext,
    ));

    return state.msg.items;
}

pub fn process(allocator: std.mem.Allocator, context: ?*anyopaque, input: []const u8) anyerror!void {
    _ = allocator;
    const state: *State = @ptrCast(@alignCast(
        context orelse return error.NullContext,
    ));

    return state.msg.appendSlice(input);
}

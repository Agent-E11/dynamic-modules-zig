//! Copy the input into the state

const std = @import("std");
const print = std.debug.print;

pub const name = "copy";

const State = struct {
    msg: []const u8,
};

pub fn init(allocator: std.mem.Allocator, context_ptr: *?*anyopaque) anyerror!void { // NOTE: The error type cannot be inferred, because wrapper.Mod expects an anyerror set
    if (context_ptr.* == null) {
        context_ptr.* = try allocator.create(State);
        const state: *State = @ptrCast(@alignCast(context_ptr.*));

        state.* = State{
            .msg = "",
        };
    }
}

pub fn display(allocator: std.mem.Allocator, context: ?*anyopaque) anyerror![]const u8 {
    _ = allocator;

    const state: *State = @ptrCast(@alignCast(
        context orelse return error.NullContext,
    ));

    return state.msg;
}

pub fn process(allocator: std.mem.Allocator, context: ?*anyopaque, input: []const u8) anyerror!void {
    _ = allocator;
    const state: *State = @ptrCast(@alignCast(
        context orelse return error.NullContext,
    ));

    state.*.msg = input;
}

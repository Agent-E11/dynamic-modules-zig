const std = @import("std");
const print = std.debug.print;

const modules = @import("wrapper").modules;

pub fn main() !void {
    for (modules) |mod| {
        mod.doThing();
    }
}

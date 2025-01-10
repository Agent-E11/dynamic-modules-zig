const std = @import("std");
const print = std.debug.print;

const modules = @import("wrapper").modules;

const Mod = struct {
    doThing: *const fn () void,
};

pub fn main() !void {
    var mods: [modules.len]Mod = undefined;
    inline for (modules, 0..) |mod, i| {
        mods[i] = Mod{
            .doThing = &mod.doThing,
        };
    }

    for (mods) |mod| {
        mod.doThing();
    }
}

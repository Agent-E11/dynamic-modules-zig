const std = @import("std");
const mod_types = @import("wrapper").mod_types;

pub const Mod = struct {
    name: []const u8,
    init: *const fn (allocator: std.mem.Allocator, context_ptr: *?*anyopaque) anyerror!void,
    display: *const fn (allocator: std.mem.Allocator, context: ?*anyopaque) anyerror![]const u8,
    process: *const fn (allocator: std.mem.Allocator, context: ?*anyopaque, input: []const u8) anyerror!void,
};

// TODO: Currently, if the imported `mod` does not have the correct
// declarations, there is an ugly compile error. I might be able to do a
// comp-time loop that checks the declarations of the module and outputs
// a custom @compileError().
pub const modules = blk: {
    var mods: [mod_types.len]Mod = undefined;
    for (mod_types, 0..) |mod, i| {
        mods[i] = Mod{
            .name = mod.name,
            .init = &mod.init,
            .display = &mod.display,
            .process = &mod.process,
        };
    }
    break :blk mods;
};

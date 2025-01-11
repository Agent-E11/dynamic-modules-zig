const std = @import("std");
const print = std.debug.print;
const eql = std.mem.eql;

const Mod = @import("modules").Mod;
const modules = @import("modules").modules;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    // TODO: The contexts might be able to be handled entirely by the modules
    // themselves. Currently the `init`, `display`, and `process` functions are
    // relatively "pure", in that they don't access state that isn't explicitly
    // passed to them. Making the modules handle their own state may break that
    // because the state might have to be a top-level `var` declaration (I can't
    // think of how it could be done any other way at the moment).
    var contexts = [_]?*anyopaque{null} ** modules.len;
    for (modules, 0..) |mod, i| {
        // TODO: If the modules handle their own contexts, then they could still
        // be passed this allocator, and they can add it to their state.
        try mod.init(allocator, &contexts[i]);
    }

    var current_mod_idx: usize = 0;
    var mod = modules[current_mod_idx];
    var context = contexts[current_mod_idx];

    while (try getInput(allocator, context, mod)) |input| {
        if (input.len > 0 and input[0] == '!') {
            const cmd = input[1..];
            if (eql(u8, cmd, "next") or eql(u8, cmd, "n")) {
                current_mod_idx = @mod(current_mod_idx + 1, modules.len);
                mod = modules[current_mod_idx];
                context = contexts[current_mod_idx];
                print("next ({})\n", .{current_mod_idx});
            } else if (eql(u8, cmd, "prev") or eql(u8, cmd, "p")) {
                if (current_mod_idx == 0) {
                    current_mod_idx = modules.len;
                }
                current_mod_idx = @mod(current_mod_idx - 1, modules.len);
                mod = modules[current_mod_idx];
                context = contexts[current_mod_idx];
                print("prev ({})\n", .{current_mod_idx});
            } else if (eql(u8, cmd, "quit") or eql(u8, cmd, "q")) {
                print("quit\n", .{});
                break;
            } else {
                print("invalid command: '{s}'\n", .{cmd});
            }
        } else {
            try mod.process(allocator, context, input);
        }
    }
    print("exiting\n", .{});
}

fn getInput(allocator: std.mem.Allocator, context: ?*anyopaque, mod: Mod) !?[]const u8 {
    const stdin = std.io.getStdIn().reader();
    print("\n{s}: '{s}'\n> ", .{ mod.name, try mod.display(allocator, context) });
    return stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize));
}

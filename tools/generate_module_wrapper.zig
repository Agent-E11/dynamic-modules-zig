const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    if (args.len != 3) fatal("wrong number of arguments.", .{});

    const output_file_path = args[1];
    const module_dir_path = args[2];
    // HACK:
    const cache_module_dir_path = output_file_path[0 .. output_file_path.len - "wrapper.zig".len]; // HACK: get dir name
    std.debug.print("cache_module_dir_path: {s}\n", .{cache_module_dir_path});

    var output_file = cwd.createFile(output_file_path, .{}) catch |err| {
        fatal("unable to open '{s}': {s}", .{ output_file_path, @errorName(err) });
    };
    defer output_file.close();

    var module_import_strs = std.ArrayList([]const u8).init(arena);
    var module_dir = cwd.openDir(module_dir_path, .{ .iterate = true }) catch |err| {
        fatal("unable to open '{s}': {s}", .{ module_dir_path, @errorName(err) });
    };
    const cache_module_dir = cwd.openDir(cache_module_dir_path, .{ .iterate = true }) catch |err| {
        fatal("unable to open '{s}': {s}", .{ cache_module_dir_path, @errorName(err) });
    };
    var it = module_dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind == .file) {
            const str = try std.fmt.allocPrint(arena, "    @import(\"./{s}\"),\n", .{entry.name});
            try module_import_strs.append(str);
            try module_dir.copyFile(entry.name, cache_module_dir, entry.name, .{});
        }
    }

    _ = try output_file.write("pub const modules = [_]type{\n");
    for (module_import_strs.items) |str| {
        _ = try output_file.write(str);
    }
    _ = try output_file.write("};");

    return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}

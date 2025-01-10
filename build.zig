const std = @import("std");
const print = std.debug.print;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const wrapper_path = createWrapperFromConfigFile(b, "./modules.json") catch |err| {
        print("{}\n", .{err});
        std.process.exit(1);
    };

    // const tool = b.addExecutable(.{
    //     .name = "generate_module_wrapper",
    //     .root_source_file = b.path("./tools/generate_module_wrapper.zig"),
    //     .target = b.host,
    // });
    //
    // const tool_step = b.addRunArtifact(tool);
    // const wrapper = tool_step.addOutputFileArg("wrapper.zig");
    // tool_step.addDirectoryArg(b.path("./modules/"));

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "dynamic-modules",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "dynamic-modules",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addAnonymousImport("wrapper", .{
        .root_source_file = wrapper_path,
    });

    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

const ModConf = struct {
    module_dir_path: ?[]const u8,
    modules: []const []const u8,
};

fn createWrapperFromConfigFile(b: *std.Build, conf_path: []const u8) !std.Build.LazyPath {
    const cwd = std.fs.cwd();
    // Read and parse config file
    const conf_file = cwd.openFile(conf_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            print("error: config file not found: {s}\n", .{conf_path});
            std.process.exit(1);
        },
        else => {
            print("error: {}\n", .{err});
            std.process.exit(1);
        },
    };

    const conf_bytes = try conf_file.readToEndAlloc(b.allocator, std.math.maxInt(usize));

    const conf_parsed = try std.json.parseFromSlice(ModConf, b.allocator, conf_bytes, .{});
    defer conf_parsed.deinit();

    // Create output directories
    try cwd.deleteTree(".generated/");
    const generated_dir = try cwd.makeOpenPath(".generated/", .{});
    const generated_module_dir = try generated_dir.makeOpenPath("modules/", .{});

    // Copy module source files to module dir

    const conf_module_dir_path = conf_parsed.value.module_dir_path orelse "./modules/";

    const conf_module_dir = cwd.openDir(
        conf_module_dir_path,
        .{ .iterate = true },
    ) catch |err| switch (err) {
        error.FileNotFound => {
            print("error: module directory not found: {s}\n", .{conf_module_dir_path});
            std.process.exit(1);
        },
        else => {
            print("error: {}\n", .{err});
            std.process.exit(1);
        },
    };

    for (conf_parsed.value.modules) |mod| {
        conf_module_dir.copyFile(mod, generated_module_dir, mod, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                print("error: could not find module {s} in module directory {s}\n", .{ mod, conf_module_dir_path });
                std.process.exit(1);
            },
            else => {
                print("error: {}\n", .{err});
                std.process.exit(1);
            },
        };
    }

    // Generate wrapper module

    const wrapper_path = ".generated/wrapper.zig";

    const wrapper_file = try cwd.createFile(wrapper_path, .{});

    _ = try wrapper_file.write(
        \\pub const Mod = struct {
        \\    doThing: *const fn() void,
        \\};
        \\
        \\const mod_types = [_]type{
        \\
    );

    for (conf_parsed.value.modules) |mod| {
        try std.fmt.format(
            wrapper_file.writer(),
            "    @import(\"./modules/{s}\"),\n",
            .{mod},
        );
    }
    _ = try wrapper_file.write("};\n\n");

    _ = try wrapper_file.write(
        \\pub const modules = blk: {
        \\    var mods: [mod_types.len]Mod = undefined;
        \\    for (mod_types, 0..) |mod, i| {
        \\        mods[i] = Mod{
        \\            .doThing = &mod.doThing,
        \\        };
        \\    }
        \\    break :blk mods;
        \\};
        \\
    );

    return b.path(wrapper_path);
}

fn contains(slice: []const []const u8, str: []const u8) bool {
    for (slice) |v| {
        if (v == str) return true;
    }
    return false;
}

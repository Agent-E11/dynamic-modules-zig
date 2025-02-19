const std = @import("std");
const print = std.debug.print;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // NOTE: I think this is a _little_ bit hacky, because it is not a run step
    // depended on by other steps. It might be fine though.
    const wrapper_path = generateWrapperFromConfigFile(b, "./modules.zon") catch |err| {
        print("{}\n", .{err});
        std.process.exit(1);
    };
    const modules = std.Build.Module.create(b, .{
        .root_source_file = b.path("tools/modules.zig"),
    });
    modules.addAnonymousImport("wrapper", .{
        .root_source_file = wrapper_path,
    });

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
    exe.root_module.addImport("modules", modules);

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

/// Parse the json configuration file and generate a wrapper file that
/// exports an array of modules.
///
/// Returns the path of the generated wrapper file.
fn generateWrapperFromConfigFile(b: *std.Build, conf_path: []const u8) !std.Build.LazyPath {
    const root_dir = b.build_root.handle;

    // Read and parse config file
    const conf_file = root_dir.openFile(conf_path, .{}) catch |err| switch (err) {
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
    const conf_bytes_z = try b.allocator.dupeZ(u8, conf_bytes); // HACK: Is there a way to _not_ duplicate it again after allocating the first time?

    var status: std.zon.parse.Status = .{};
    const conf = std.zon.parse.fromSlice(
        ModConf,
        b.allocator,
        conf_bytes_z,
        //".{.module_dir_path = \"./modules\", .modules = .{\"copy.zig\", \"self-contained.zig\"}}",
        //".{.modules=.{\"test\",},", // HACK:?
        &status,
        .{},
    ) catch |err| switch (err) {
        error.ParseZon => {
            print("error while parsing configuration file: '{}{s}'\n", .{ b.build_root, conf_path });
            print("{}", .{status});
            std.process.exit(1);
        },
        else => @panic(""),
    }; // HACK:

    // const conf_parsed = std.json.parseFromSlice(ModConf, b.allocator, conf_bytes, .{}) catch |err| switch (err) {
    //     error.SyntaxError => {
    //         print("error: there is a syntax error in config file: {s}\n", .{conf_path});
    //         std.process.exit(1);
    //     },
    //     else => return err,
    // };
    // defer conf_parsed.deinit();

    // Create output directories
    try root_dir.deleteTree(".generated/");
    const generated_dir = try root_dir.makeOpenPath(".generated/", .{});
    const generated_module_dir = try generated_dir.makeOpenPath("modules/", .{});

    // Copy module source files to module dir

    const conf_module_dir_path = conf.module_dir_path orelse "./modules/";

    const conf_module_dir = root_dir.openDir(
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

    for (conf.modules) |mod| {
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

    const wrapper_file = try root_dir.createFile(wrapper_path, .{});

    _ = try wrapper_file.write(
        \\//! This module is generated by `build.zig`. Don't edit it.
        \\
        \\pub const mod_types = [_]type{
        \\
    );

    for (conf.modules) |mod| {
        try std.fmt.format(
            wrapper_file.writer(),
            "    @import(\"./modules/{s}\"),\n",
            .{mod},
        );
    }
    _ = try wrapper_file.write("};\n\n");

    return b.path(wrapper_path);
}

fn contains(slice: []const []const u8, str: []const u8) bool {
    for (slice) |v| {
        if (v == str) return true;
    }
    return false;
}

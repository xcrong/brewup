const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Minimal binary without UPX: strip symbols and omit unwind tables in
    // release modes only (Debug keeps them for stack traces). Saves ~7%.
    // single_threaded is NOT an option: runBrewCommand uses pump threads.
    const is_release = optimize != .Debug;

    const exe = b.addExecutable(.{
        .name = "brewup",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = is_release,
            .unwind_tables = if (is_release) .none else null,
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run brewup");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    // NOTE: intentionally no dependOn(getInstallStep()) so that
    // `zig build run` / `make dry-run` never overwrites zig-out/bin/brewup.
    if (b.args) |args| run_cmd.addArgs(args);

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe_tests = b.addTest(.{ .root_module = test_mod });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_tests.step);
}

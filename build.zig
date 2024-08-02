const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sap = b.addModule("sap", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const docs = b.addInstallDirectory(.{
        .source_dir = b.addStaticLibrary(.{
            .name = "sap",
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }).getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&docs.step);

    for ([_][]const u8{
        "full",
    }) |example| {
        const run_step = b.step(b.fmt("run-{s}", .{example}), b.fmt("Run {s}.zig example", .{example}));
        const exe = b.addExecutable(.{
            .name = example,
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{example})),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("sap", sap);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&b.addInstallArtifact(exe, .{}).step);

        if (b.args) |args|
            run_cmd.addArgs(args);

        run_step.dependOn(&run_cmd.step);
    }
}

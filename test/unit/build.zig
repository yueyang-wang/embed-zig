const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep = b.dependency("embed_zig", .{
        .target = target,
        .optimize = optimize,
        .speexdsp = true,
        .stb_truetype = true,
    });

    const embed_mod = dep.module("embed");

    const test_root = b.createModule(.{
        .root_source_file = b.path("mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_root.addImport("embed", embed_mod);

    const tests = b.addTest(.{ .root_module = test_root });
    tests.linkLibrary(dep.artifact("embed_link"));
    const run_tests = b.addRunArtifact(tests);

    b.default_step.dependOn(&tests.step);

    b.step("test", "Run all unit tests").dependOn(&run_tests.step);
}

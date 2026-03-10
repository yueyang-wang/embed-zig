const std = @import("std");
const esp = @import("esp");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const esp_dep = b.dependency("esp", .{});
    const embed_zig_dep = esp_dep.builder.dependency("embed_zig", .{});

    _ = esp.idf.build.registerApp(b, "audio_engine_102", .{
        .target = target,
        .optimize = optimize,
        .extra_zig_modules = &.{
            .{ .name = "embed", .path = embed_zig_dep.path("src/mod.zig") },
            .{ .name = "board_hw", .path = b.path("bsp.zig") },
            .{ .name = "test_firmware", .path = embed_zig_dep.path("test/firmware/mod.zig") },
        },
    });
}

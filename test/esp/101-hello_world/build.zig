const std = @import("std");
const esp = @import("esp");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const esp_dep = b.dependency("esp", .{});
    const embed_zig_dep = esp_dep.builder.dependency("embed_zig", .{});

    _ = esp.idf.build.registerApp(b, "hello_world_101", .{
        .target = target,
        .optimize = optimize,
        .extra_zig_modules = &.{
            .{ .name = "board_hw", .path = b.path("bsp.zig") },
            .{ .name = "test_firmware", .path = embed_zig_dep.path("test/firmware/101-hello_world/app.zig") },
        },
    });
}

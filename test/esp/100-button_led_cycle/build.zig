const std = @import("std");
const espz = @import("espz");

const default_board_file = "board/esp32s3_devkit.zig";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const board_file = b.option([]const u8, "board", "Board sdkconfig profile Zig file path") orelse default_board_file;
    const build_dir = b.option([]const u8, "build_dir", "Directory for all generated workflow files") orelse "build";

    const runtime = espz.workflow.externalRuntimeOptionsFromBuild(b);

    const embed_zig_dep = b.dependency("embed_zig", .{});

    const extra_modules = b.allocator.alloc(espz.workflow.ExtraZigModule, 2) catch @panic("OOM");
    extra_modules[0] = .{
        .name = "embed_zig",
        .path = embed_zig_dep.path("src/root.zig"),
    };
    extra_modules[1] = .{
        .name = "test_firmware",
        .path = embed_zig_dep.path("test/firmware/root.zig"),
        .deps = &.{"embed_zig"},
    };

    _ = espz.registerExternalExample(b, .{
        .target = target,
        .optimize = optimize,
        .app_name = "button_led_cycle_100",
        .board_file = board_file,
        .build_dir = build_dir,
        .compile_check_with_idf_module = false,
        .runtime = runtime,
        .extra_zig_modules = extra_modules,
    });
}

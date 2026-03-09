const std = @import("std");
const espz = @import("espz");

const default_board_file = "board/esp32s3_devkit.zig";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const board_file = b.option([]const u8, "board", "Board sdkconfig profile Zig file path") orelse default_board_file;
    const build_dir = b.option([]const u8, "build_dir", "Directory for all generated workflow files") orelse "build";

    const rt = espz.workflow.externalRuntimeOptionsFromBuild(b);

    const embed_zig_dep = b.dependency("embed_zig", .{});

    const runtime_path = embed_zig_dep.path("src/runtime/root.zig");
    const hal_path = embed_zig_dep.path("src/hal/root.zig");
    const runtime_esp_path = embed_zig_dep.path("src/runtime/esp/root.zig");
    const hal_esp_path = embed_zig_dep.path("src/hal/esp/root.zig");
    const event_path = embed_zig_dep.path("src/pkg/event/root.zig");
    const flux_path = embed_zig_dep.path("src/pkg/flux/root.zig");
    const app_runtime_path = embed_zig_dep.path("src/pkg/app/root.zig");
    const test_firmware_path = embed_zig_dep.path("test/firmware/root.zig");

    const ui_led_strip_path = embed_zig_dep.path("src/pkg/ui/led_strip/root.zig");
    const ui_render_path = embed_zig_dep.path("src/pkg/ui/render/framebuffer/root.zig");

    const extra_modules = b.allocator.alloc(espz.workflow.ExtraZigModule, 10) catch @panic("OOM");
    extra_modules[0] = .{ .name = "embed/runtime", .path = runtime_path };
    extra_modules[1] = .{ .name = "embed/hal", .path = hal_path };
    extra_modules[2] = .{ .name = "runtime_esp", .path = runtime_esp_path, .deps = &.{"embed/runtime"} };
    extra_modules[3] = .{ .name = "hal_esp", .path = hal_esp_path, .deps = &.{"embed/hal"} };
    extra_modules[4] = .{ .name = "embed/event", .path = event_path, .deps = &.{ "embed/runtime", "embed/hal" } };
    extra_modules[5] = .{ .name = "embed/flux", .path = flux_path };
    extra_modules[6] = .{ .name = "embed/app", .path = app_runtime_path, .deps = &.{ "embed/runtime", "embed/event", "embed/flux" } };
    extra_modules[7] = .{ .name = "embed/ui/led_strip", .path = ui_led_strip_path, .deps = &.{"embed/hal"} };
    extra_modules[8] = .{ .name = "embed/ui/render", .path = ui_render_path };
    extra_modules[9] = .{ .name = "test_firmware", .path = test_firmware_path, .deps = &.{ "embed/runtime", "embed/hal", "embed/event", "embed/flux", "embed/app", "embed/ui/led_strip", "embed/ui/render" } };

    _ = espz.registerApp(b, .{
        .target = target,
        .optimize = optimize,
        .app_name = "button_led_cycle_100",
        .board_file = board_file,
        .build_dir = build_dir,
        .compile_check_with_idf_module = false,
        .runtime = rt,
        .extra_zig_modules = extra_modules,
    });
}

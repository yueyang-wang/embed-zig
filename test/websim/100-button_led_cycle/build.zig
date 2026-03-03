const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const firmware = b.createModule(.{
        .root_source_file = b.path("../../firmware/100-button_led_cycle/root.zig"),
    });

    const websim = b.createModule(.{
        .root_source_file = b.path("../../../tools/websim/main.zig"),
        .imports = &.{
            .{ .name = "firmware", .module = firmware },
        },
    });

    const exe = b.addExecutable(.{
        .name = "button_led_cycle_sim",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "websim", .module = websim },
            },
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the simulator");
    run_step.dependOn(&run_cmd.step);
}

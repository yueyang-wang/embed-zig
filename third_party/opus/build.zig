const std = @import("std");

const default_repo = "https://github.com/xiph/opus.git";
const default_source_path = "vendor/opus";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const opus_commit = b.option([]const u8, "opus_commit", "Pin to specific opus commit");
    const opus_define = b.option([]const u8, "opus_define", "Optional user C macro for opus (NAME or NAME=VALUE)");
    const fixed_point = b.option(bool, "opus_fixed_point", "Build opus with FIXED_POINT (default: true for MCU)") orelse true;

    const ensure_source = ensureSource(b, opus_commit);

    const opus_module = b.addModule("opus", .{
        .root_source_file = b.path("src.zig"),
        .target = target,
        .optimize = optimize,
    });
    opus_module.addIncludePath(b.path("c_include"));
    if (fixed_point) {
        opus_module.addCMacro("FIXED_POINT", "1");
    }
    applyUserDefine(opus_module, opus_define);

    const test_step = b.step("test", "Run opus API tests");
    const test_compile = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_compile.root_module.addIncludePath(b.path("c_include"));
    if (fixed_point) {
        test_compile.root_module.addCMacro("FIXED_POINT", "1");
    }
    applyUserDefine(test_compile.root_module, opus_define);
    test_compile.step.dependOn(ensure_source);
    test_step.dependOn(&b.addRunArtifact(test_compile).step);
}

fn ensureSource(b: *std.Build, commit: ?[]const u8) *std.Build.Step {
    const clone_or_fetch = b.addSystemCommand(&.{
        "/bin/sh",
        "-c",
        b.fmt(
            "set -eu; " ++
                "if [ ! -d '{s}/.git' ]; then " ++
                "  mkdir -p \"$(dirname '{s}')\"; " ++
                "  git clone --depth 1 {s} '{s}'; " ++
                "fi",
            .{ default_source_path, default_source_path, default_repo, default_source_path },
        ),
    });

    var last: *std.Build.Step = &clone_or_fetch.step;

    if (commit) |sha| {
        const checkout = b.addSystemCommand(&.{
            "/bin/sh",
            "-c",
            b.fmt(
                "set -eu; " ++
                    "git -C '{s}' fetch --depth 1 origin {s}; " ++
                    "git -C '{s}' checkout --detach {s}",
                .{ default_source_path, sha, default_source_path, sha },
            ),
        });
        checkout.step.dependOn(last);
        last = &checkout.step;
    }

    const sync_headers = b.addSystemCommand(&.{
        "/bin/sh",
        "-c",
        b.fmt(
            "set -eu; " ++
                "mkdir -p c_include/opus; " ++
                "cp -f {s}/include/*.h c_include/opus/",
            .{default_source_path},
        ),
    });
    sync_headers.step.dependOn(last);

    return &sync_headers.step;
}

fn applyUserDefine(module: *std.Build.Module, define: ?[]const u8) void {
    if (define) |raw| {
        if (raw.len == 0) return;
        if (std.mem.indexOfScalar(u8, raw, '=')) |idx| {
            module.addCMacro(raw[0..idx], raw[idx + 1 ..]);
        } else {
            module.addCMacro(raw, "1");
        }
    }
}

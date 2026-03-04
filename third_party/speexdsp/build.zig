const std = @import("std");

const default_repo = "https://github.com/xiph/speexdsp.git";
const default_source_path = "vendor/speexdsp";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const speexdsp_commit = b.option([]const u8, "speexdsp_commit", "Pin to specific speexdsp commit");
    const speexdsp_define = b.option([]const u8, "speexdsp_define", "Optional user C macro for speexdsp (NAME or NAME=VALUE)");
    const fixed_point = b.option(bool, "speexdsp_fixed_point", "Build with FIXED_POINT (default: true for MCU)") orelse true;

    const ensure_source = ensureSource(b, speexdsp_commit);

    // ── static C library ──────────────────────────────────────────────────

    const wf = b.addWriteFiles();
    const empty_root = wf.add("empty.zig", "");
    const speexdsp_lib = b.addLibrary(.{
        .name = "speexdsp",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = empty_root,
            .target = target,
            .optimize = optimize,
        }),
    });
    speexdsp_lib.linkLibC();

    const c_flags: []const []const u8 = if (fixed_point)
        &.{ "-DUSE_KISS_FFT", "-DFIXED_POINT", "-DEXPORT=", "-fwrapv" }
    else
        &.{ "-DUSE_KISS_FFT", "-DEXPORT=", "-fwrapv" };

    const c_sources = [_][]const u8{
        "vendor/speexdsp/libspeexdsp/preprocess.c",
        "vendor/speexdsp/libspeexdsp/jitter.c",
        "vendor/speexdsp/libspeexdsp/mdf.c",
        "vendor/speexdsp/libspeexdsp/fftwrap.c",
        "vendor/speexdsp/libspeexdsp/filterbank.c",
        "vendor/speexdsp/libspeexdsp/resample.c",
        "vendor/speexdsp/libspeexdsp/buffer.c",
        "vendor/speexdsp/libspeexdsp/scal.c",
        "vendor/speexdsp/libspeexdsp/kiss_fft.c",
        "vendor/speexdsp/libspeexdsp/kiss_fftr.c",
    };

    for (c_sources) |src| {
        speexdsp_lib.addCSourceFile(.{ .file = b.path(src), .flags = c_flags });
    }
    speexdsp_lib.addIncludePath(b.path("c_include"));
    speexdsp_lib.addIncludePath(b.path("vendor/speexdsp/libspeexdsp"));
    applyUserDefine(speexdsp_lib.root_module, speexdsp_define);
    speexdsp_lib.step.dependOn(ensure_source);

    // ── zig module ────────────────────────────────────────────────────────

    const speexdsp_module = b.addModule("speexdsp", .{
        .root_source_file = b.path("src.zig"),
        .target = target,
        .optimize = optimize,
    });
    speexdsp_module.addIncludePath(b.path("c_include"));
    applyUserDefine(speexdsp_module, speexdsp_define);

    // ── tests ─────────────────────────────────────────────────────────────

    const test_step = b.step("test", "Run speexdsp API tests");
    const test_compile = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_compile.root_module.addIncludePath(b.path("c_include"));
    applyUserDefine(test_compile.root_module, speexdsp_define);
    test_compile.linkLibrary(speexdsp_lib);
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
                "mkdir -p c_include/speex; " ++
                "cp -f {s}/include/speex/*.h c_include/speex/; " ++
                "cat > c_include/speex/speexdsp_config_types.h <<'CFGEOF'\n" ++
                "#ifndef __SPEEX_TYPES_H__\n" ++
                "#define __SPEEX_TYPES_H__\n" ++
                "#include <stdint.h>\n" ++
                "typedef int16_t spx_int16_t;\n" ++
                "typedef uint16_t spx_uint16_t;\n" ++
                "typedef int32_t spx_int32_t;\n" ++
                "typedef uint32_t spx_uint32_t;\n" ++
                "#endif\n" ++
                "CFGEOF",
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

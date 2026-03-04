const std = @import("std");

const default_repo = "https://github.com/xiph/ogg.git";
const default_source_path = "vendor/ogg";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ogg_commit = b.option([]const u8, "ogg_commit", "Pin to specific ogg commit");
    const ogg_define = b.option([]const u8, "ogg_define", "Optional user C macro for ogg (NAME or NAME=VALUE)");

    const ensure_source = ensureSource(b, ogg_commit);

    const ogg_module = b.addModule("ogg", .{
        .root_source_file = b.path("src.zig"),
        .target = target,
        .optimize = optimize,
    });
    ogg_module.addIncludePath(b.path("c_include"));
    applyUserDefine(ogg_module, ogg_define);

    const files = b.addWriteFiles();
    const empty_root = files.add("empty.zig", "");
    const ogg_lib = b.addLibrary(.{
        .name = "ogg",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = empty_root,
            .target = target,
            .optimize = optimize,
        }),
    });
    ogg_lib.addCSourceFile(.{ .file = b.path("vendor/ogg/src/bitwise.c") });
    ogg_lib.addCSourceFile(.{ .file = b.path("vendor/ogg/src/framing.c") });
    ogg_lib.addIncludePath(b.path("c_include"));
    applyUserDefine(ogg_lib.root_module, ogg_define);
    ogg_lib.step.dependOn(ensure_source);

    const test_step = b.step("test", "Run ogg API tests");
    const test_compile = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_compile.root_module.addIncludePath(b.path("c_include"));
    applyUserDefine(test_compile.root_module, ogg_define);
    test_compile.linkLibrary(ogg_lib);
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
                "mkdir -p c_include/ogg; " ++
                "cp -f {s}/include/ogg/ogg.h c_include/ogg/; " ++
                "cp -f {s}/include/ogg/os_types.h c_include/ogg/; " ++
                "cat > c_include/ogg/config_types.h <<'CFGEOF'\n" ++
                "#ifndef _OGG_CONFIG_TYPES_H\n" ++
                "#define _OGG_CONFIG_TYPES_H\n" ++
                "#include <stdint.h>\n" ++
                "typedef int16_t ogg_int16_t;\n" ++
                "typedef uint16_t ogg_uint16_t;\n" ++
                "typedef int32_t ogg_int32_t;\n" ++
                "typedef uint32_t ogg_uint32_t;\n" ++
                "typedef int64_t ogg_int64_t;\n" ++
                "typedef uint64_t ogg_uint64_t;\n" ++
                "#endif\n" ++
                "CFGEOF",
            .{ default_source_path, default_source_path },
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

const std = @import("std");
const builtin = @import("builtin");

const emulator = "citra";
const flags = .{"-lctru"};
const devkitpro = "/opt/devkitpro";

pub fn build(b: *std.build.Builder) void {
    const target: std.zig.CrossTarget = .{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.mpcore },
    };
    const optimize = b.standardOptimizeOption(.{});

    const extension = comptime builtin.target.exeFileExt();

    const obj = b.addObject(.{
        .name = "zig-3ds",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    obj.linkLibC();
    obj.setLibCFile(.{ .path = "libc.txt" });
    obj.addIncludePath(.{ .path = devkitpro ++ "/libctru/include" });
    obj.addIncludePath(.{ .path = devkitpro ++ "/portlibs/3ds/include" });

    const obj_install = b.addInstallArtifact(obj, .{
        .dest_dir = .{ .override = .prefix },
    });

    const elf = b.addSystemCommand(&(.{
        devkitpro ++ "/devkitARM/bin/arm-none-eabi-gcc" ++ extension,
        "-g",
        "-march=armv6k",
        "-mtune=mpcore",
        "-mfloat-abi=hard",
        "-mtp=soft",
        "-Wl,-Map,zig-out/zig-3ds.map",
        "-specs=" ++ devkitpro ++ "/devkitARM/arm-none-eabi/lib/3dsx.specs",
        "zig-out/zig-3ds.o",
        "-L" ++ devkitpro ++ "/libctru/lib",
        "-L" ++ devkitpro ++ "/portlibs/3ds/lib",
    } ++ flags ++ .{
        "-o",
        "zig-out/zig-3ds.elf",
    }));

    const dsx = b.addSystemCommand(&.{
        devkitpro ++ "/tools/bin/3dsxtool" ++ extension,
        "zig-out/zig-3ds.elf",
        "zig-out/zig-3ds.3dsx",
    });

    b.default_step.dependOn(&dsx.step);
    dsx.step.dependOn(&elf.step);
    elf.step.dependOn(&obj_install.step);

    const run_step = b.step("run", "Run in Citra");
    const citra = b.addSystemCommand(&.{ emulator, "zig-out/zig-3ds.3dsx" });
    run_step.dependOn(&dsx.step);
    run_step.dependOn(&citra.step);
}

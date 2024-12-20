const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const devkitpro = std.process.getEnvVarOwned(b.allocator, "DEVKITPRO") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => @panic("Please set $DEVKITPRO"),
        error.InvalidWtf8 => @panic("Invalid WTF-8"),
        error.OutOfMemory => @panic("OOM"),
    };

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.mpcore },
    });
    const optimize = b.standardOptimizeOption(.{});

    const extension = comptime builtin.target.exeFileExt();

    const obj = b.addObject(.{
        .name = "zig-3ds",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    obj.linkLibC();
    obj.setLibCFile(b.path("libc.txt"));
    obj.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ devkitpro, "libctru/include" }) });
    obj.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ devkitpro, "portlibs/3ds/include" }) });

    const obj_install = b.addInstallArtifact(obj, .{
        .dest_dir = .{ .override = .prefix },
    });

    const elf = b.addSystemCommand(&(.{
        b.pathJoin(&.{ devkitpro, "devkitARM/bin/arm-none-eabi-gcc" ++ extension }),
        "-g",
        "-march=armv6k",
        "-mtune=mpcore",
        "-mfloat-abi=hard",
        "-mtp=soft",
        "-Wl,-Map,zig-out/zig-3ds.map",
        b.fmt("-specs={s}", .{b.pathJoin(&.{ devkitpro, "devkitARM/arm-none-eabi/lib/3dsx.specs" })}),
        "zig-out/zig-3ds.o",
        b.fmt("-L{s}", .{b.pathJoin(&.{ devkitpro, "libctru/lib" })}),
        b.fmt("-L{s}", .{b.pathJoin(&.{ devkitpro, "portlibs/3ds/lib" })}),
        "-lctru",
        "-o",
        "zig-out/zig-3ds.elf",
    }));

    const dsx = b.addSystemCommand(&.{
        b.pathJoin(&.{ devkitpro, "tools/bin/3dsxtool" ++ extension }),
        "zig-out/zig-3ds.elf",
        "zig-out/zig-3ds.3dsx",
    });

    b.default_step.dependOn(&dsx.step);
    dsx.step.dependOn(&elf.step);
    elf.step.dependOn(&obj_install.step);

    const lime3ds = b.addSystemCommand(&.{ "lime3ds", "zig-out/zig-3ds.3dsx" });
    lime3ds.step.dependOn(b.default_step);

    const run_step = b.step("run", "Run in Lime3DS");
    run_step.dependOn(&lime3ds.step);
}

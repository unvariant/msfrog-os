const std = @import("std");

const Target = std.Target;
const Feature = Target.Cpu.Feature;
const CrossTarget = std.zig.CrossTarget;

const features = Target.x86.Feature;

const cp_cmd_str = [_][] const u8 { "cp", "zig-out/bin/BOOTX64.efi", "uefi/shared/EFI/BOOT/BOOTX64.EFI" };
const run_cmd_str = [_][] const u8
    { "qemu-system-x86_64"
    , "--bios", "uefi/debug/OVMF.fd"
    , "-L", "uefi/debug"
    , "-drive", "file=fat:rw:uefi/shared,format=raw"
    , "-net", "none"
    , "-debugcon", "file:uefi/debug.log", "-global", "isa-debugcon.iobase=0x402" };

pub fn build(b: *std.Build) void {
    var disabled_features = Feature.Set.empty;
    var enabled_features = Feature.Set.empty;

    disabled_features.addFeature(@enumToInt(features.mmx));
    disabled_features.addFeature(@enumToInt(features.sse));
    disabled_features.addFeature(@enumToInt(features.sse2));
    disabled_features.addFeature(@enumToInt(features.avx));
    disabled_features.addFeature(@enumToInt(features.avx2));
    enabled_features.addFeature(@enumToInt(features.soft_float));

    const target = CrossTarget{
        .cpu_arch = Target.Cpu.Arch.x86_64,
        .os_tag = Target.Os.Tag.uefi,
        .abi = Target.Abi.none,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    };

    const optimize = .ReleaseFast;

    const stub = b.addStaticLibrary(.{
        .name = "libstub.a",
        .root_source_file = .{ .path = "src/stub.zig" },
        .target = target,
        .optimize = optimize,
    });
    stub.install();

    const exe = b.addExecutable(.{
        .name = "BOOTX64",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.step.dependOn(&stub.step);
    exe.linkLibrary(stub);
    exe.install();

    const cp_cmd = b.addSystemCommand(&[_][] const u8
    { "cp"
    , "zig-out/bin/BOOTX64.efi"
    , "uefi/shared/EFI/BOOT/BOOTX64.EFI"
    });
    const run_cmd = b.addSystemCommand(&[_][] const u8
    { "qemu-system-x86_64"
    , "--bios", "uefi/OVMF.fd"
    , "-L", "uefi/debug"
    , "-drive", "file=fat:rw:uefi/shared,format=raw"
    , "-net", "none"
    , "-debugcon", "file:uefi/debug.log", "-global", "isa-debugcon.iobase=0x402"
    });
    const run_step = b.step("run", "run msfrog run");

    run_step.dependOn(&exe.step);
    run_step.dependOn(&cp_cmd.step);
    run_step.dependOn(&run_cmd.step);
}

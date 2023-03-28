# MSFROG OS
This repository is dedicated to the msfroggenerator2 problem from picoCTF 2023
for stealing my sanity for half the competition.

**NOTE**: MSFROG OS was developed on zig version `0.11.0-dev.2245+dc6b05408` and macos.

# Zig and UEFI
Zig makes creating UEFI applications ridiculously simple. It supports UEFI as a
compilation target and includes all the necessary UEFI structure definitions in
the standard library.

## Notes
### Building locally
First grab UEFI bios from [here](https://github.com/tianocore/tianocore.github.io/wiki/OVMF).
They do not provide release binaries and you have to compile the package yourself. Once done
building copy the `OVMF.fd` file into the project `uefi` directory.
This is required to provide `qemu` a UEFI compatible bios for emulation.

- To build locally run `zig build`.
  - This will create the UEFI PE executable in `zig-out/bin/BOOTX64.EFI`.
- To deploy using qemu run `zig build run`.
  - Must run `zig build` first to create the executable.
- To create a disk image run `make disk`.
  - Must run `zig build` first to create the executable.
- To deploy using the created disk image run `make run`.
- To populate the `src/frames` directory copy the target video into the project root
and rename it to `rick-roll-video`. Run `make frames` to extract the first 33 seconds of
the video into a series of 160x100 targa frames.

### stub.zig
Due to a [bug](https://reviews.llvm.org/D4927) in llvm, you have to manually create
the symbols otherwise llvm will complain and refuse to link. This is solved by manually
creating the symbols and exporting them in a stub file. The symbols seem to be dealing
with 16 bit floating point numbers which I know my program does not use at all, so
they can be safely stubbed out and ignored.

### src/frames
This folder is meant to hold the targa frames for the rickroll video, and are then
concatenated into one large file that is embedded into the end executable. I did this
because I was too lazy to figure out how to read from the disk in UEFI. See `Makefile`
for commands to convert videos to targa frames.

### Makefile
Embedding system commands into `build.zig` is a pain so I usually fallback to using
makefiles instead.

# Resources
- [UEFI specification](https://uefi.org/specs/UEFI/2.10/index.html)
- [ziglang documentation](https://ziglang.org/documentation/master/) (master branch)
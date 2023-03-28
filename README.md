# MSFROG OS
This repository is dedicated to the msfroggenerator2 problem from picoCTF 2023
for stealing my sanity for half the competition.

**NOTE**: MSFROG OS was developed on zig version `0.11.0-dev.2245+dc6b05408` and macos.

# Zig and UEFI
Zig makes creating UEFI applications ridiculously simple. It supports UEFI as a
compilation target and includes all the necessary UEFI structure definitions in
the standard library.

## Notes
### stub.zig
Due to a [bug](https://reviews.llvm.org/D4927) in llvm, you have to manually create
the symbols otherwise llvm will complain and refuse to link. This is solved by manually
creating the symbols and exporting them in a stub file. The symbols seem to be dealing
with 16 bit floating point numbers which I know my program does not use at all, so
they can be safely stubbed out and ignored.

### src/frames
This folder is meant to hold the targa frames for the rickroll video, and are then
concatonated into one large file that is embedded into the end executable. I did this
because I was too lazy to figure out how to read from the disk in UEFI. See `Makefile`
for commands to convert videos to targa frames.

### Makefile
Embedding system commands into `build.zig` is a pain so I usually fallback to using
makefiles instead.

# Resources
- [UEFI specification](https://uefi.org/specs/UEFI/2.10/index.html)
- [ziglang documentation](https://ziglang.org/documentation/master/) (master branch)
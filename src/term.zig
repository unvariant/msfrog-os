const std = @import("std");
const arch = @import("arch.zig");

const math = std.math;
const mem = std.mem;
const uefi = std.os.uefi;
const heap = uefi.pool_allocator;
const str16 = std.unicode.utf8ToUtf16LeStringLiteral;

const Writer = std.io.Writer;
pub const Stdout = uefi.protocols.SimpleTextOutputProtocol;
pub const Stdin = uefi.protocols.SimpleTextInputProtocol;
pub const InputKey = uefi.protocols.InputKey;

pub var stdout: *Stdout = undefined;
pub var stdin: *Stdin = undefined;
pub var columns: usize = undefined;
pub var rows: usize = undefined;

// The console output protocol interprets \n as a command to move the cursor down
// without returning to column zero.
// \r is interpreted as a command to move the cursor to column zero, without affecting the row.
// In order to move down and reset the line \n\r or \r\n is required.

pub fn init() void {
    if (uefi.system_table.con_out) |con_out| {
        stdout = con_out;
        _ = stdout.queryMode(stdout.mode.mode, &columns, &rows);
    } else {
        arch.hang();
    }

    if (uefi.system_table.con_in) |con_in| {
        stdin = con_in;
    } else {
        // can print an error here because stdout is
        // guaranteed to be initialized already
        @panic("failed to initialize stdin");
    }

    _ = stdout.reset(false);
    _ = stdout.setAttribute(0x0F);
    _ = stdout.enableCursor(true);
}

pub fn waitForKey() InputKey {
    var idx: usize = undefined;
    var key: InputKey = undefined;
    _ = uefi.system_table.boot_services.?.waitForEvent(1, @as([*]const uefi.Event, @ptrCast(&stdin.wait_for_key)), &idx);
    _ = stdin.readKeyStroke(&key);
    return key;
}

pub fn getline(prompt: []const u8, buffer: []u8) usize {
    var offset: usize = 0;

    finished: while (true) {
        printf("{s}", .{prompt});

        while (offset < buffer.len) {
            const key = @as(u8, @truncate(waitForKey().unicode_char));
            switch (key) {
                0x0A, 0x0D => break :finished,
                0x08 => if (offset > 0) {
                    printf("{c}", .{key});
                    offset -= 1;
                },
                else => {
                    printf("{c}", .{key});
                    buffer[offset] = key;
                    offset += 1;
                },
            }
        }

        printf("\r\ninput too long.\r\nmax input length is {} characters.\r\nplease re-enter input. YARRR\r\n", .{buffer.len});
        offset = 0;
    }
    printf("\r\n", .{});
    return offset;
}

const writer = Writer(void, error{}, writeFn){ .context = {} };

fn writeFn(_: void, string: []const u8) error{}!usize {
    write8(string);
    return string.len;
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    writer.print(format, args) catch unreachable;
}

pub fn write8(string: []const u8) void {
    // Converts u8 str to u16 str in fixed size blocks
    // to avoid dynamic allocation.
    // This is required because the UEFI output protocol
    // expects u16 strs.
    var buf = [_:0]u16{0} ** 17;
    var base: usize = 0;

    while (base < string.len) {
        const len = @min(16, string.len - base);
        for (0..len) |i| {
            buf[i] = @as(u16, @intCast(string[base + i]));
        }
        buf[len] = 0;
        _ = stdout.outputString(&buf);
        base += len;
    }
}

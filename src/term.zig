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

pub fn init() void {
    if (uefi.system_table.con_out) |con_out| {
        stdout = con_out;
        _ = stdout.queryMode(stdout.mode.mode, &columns, &rows);
    } else {
        write8("failed to initialize stdout\r\n");
        arch.hang();
    }

    if (uefi.system_table.con_in) |con_in| {
        stdin = con_in;
    } else {
        printf("failed to initialize stdin\r\n", .{});
        arch.hang();
    }

    _ = stdout.reset(false);
    _ = stdout.setAttribute(0x0F);
    _ = stdout.enableCursor(true);
}

pub fn waitForKey() InputKey {
    var idx: usize = undefined;
    var key: InputKey = undefined;
    _ = uefi.system_table.boot_services.?.waitForEvent(1, @ptrCast([*]const uefi.Event, &stdin.wait_for_key), &idx);
    _ = stdin.readKeyStroke(&key);
    return key;
}

pub fn getline (prompt: []const u8, buffer: []u8) usize {
    printf("{s}", .{ prompt });
    var offset: usize = 0;
    while (true) {
        const key = @truncate(u8, waitForKey().unicode_char);
        switch (key) {
            0x0A, 0x0D => break,
            0x08 => if (offset > 0) {
                printf("{c}", .{ key });
                offset -= 1;
            },
            else => {
                printf("{c}", .{ key });
                buffer[offset] = key;
                offset += 1;
            },
        }

        if (offset >= buffer.len) {
            printf("input too long.\r\nmax input length is {} characters.\r\nplease re-enter input.\r\n", .{ buffer.len });
            offset = 0;
        }
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

pub fn write16(string: []const u16) void {
    var buf = [_:0]u16{0} ** 17;
    var base: usize = 0;

    while (base < string.len) {
        const slice_len = math.min(16, string.len - base);
        mem.copy(u16, buf, string[base .. base + slice_len]);
        _ = stdout.outputString(&buf);
    }
}

pub fn write8(string: []const u8) void {
    var buf = [_:0]u16{0} ** 17;
    var base: usize = 0;

    while (base < string.len) {
        const len = math.min(16, string.len - base);
        for (0..len) |i| {
            buf[i] = @intCast(u16, string[base + i]);
        }
        buf[len] = 0;
        _ = stdout.outputString(&buf);
        base += len;
    }
}

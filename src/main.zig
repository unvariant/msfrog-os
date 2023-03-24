const std = @import("std");
const builtin = std.builtin;
const arch = @import("arch.zig");
const term = @import("term.zig");
const uefi = std.os.uefi;
const mem = std.mem;
const fmt = std.fmt;

const GraphicsProtocol = uefi.protocols.GraphicsOutputProtocol;

const logo = [_][]const u8{
    \\ __  __  _____ ______ _____   ____   _____    ____   _____ 
    ,
    \\|  \/  |/ ____|  ____|  __ \ / __ \ / ____|  / __ \ / ____|
    ,
    \\| |\/| |\___ \|  __| |  _  /| |  | | | |_ | | |  | |\___ \ 
    ,
    \\| |  | |____) | |    | | \ \| |__| | |__| | | |__| |____) |
    ,
    \\|_|  |_|_____/|_|    |_|  \_\\____/ \_____|  \____/|_____/ 
    ,
    \\===========================================================
    ,
    "\r\n"
};

pub fn main() noreturn {
    term.init();

    for (logo) |line| {
        term.printf("{s}\r\n", .{ line });
    }

    var server_buffer = [_]u8{0} ** 128;
    var port_buffer = [_]u8{0} ** 128;
    const server_len = term.getline("[+] enter the picoctf server: ", &server_buffer);
    const port_len = term.getline("[+] enter the picoctf port: ", &port_buffer);

    const port = fmt.parseInt(u16, port_buffer[0 .. port_len], 10) catch |err| {
        @panic(@errorName(err));
    };

    const server = server_buffer[0 .. server_len];
    if (!mem.eql(u8, server, "saturn.picoctf.net")) {
        term.printf("failed to connect to {s}:{}\r\n", .{ server, port });
        @panic("connection error");
    }

    term.printf("[+] connecting to {s}:{}\r\n", .{ server, port });
    term.printf("[+] confirm launch of automated solution of msfroggenerator2\r\n", .{});

    while (true) {
        term.printf("answer yes or no (y/n): ", .{});
        const key = @truncate(u8, term.waitForKey().unicode_char);
        term.printf("{c}\r\n", .{ key });

        switch (key) {
            'y' => break,
            'n' => {
                term.printf("Thats too bad...\r\n", .{});
                arch.hang();
            },
            else => {},
        }
    }

    term.printf("well you asked for it...\r\n", .{});
    rickroll();

    arch.hang();
}

const frame = @embedFile("video.raw");

// see: http://paulbourke.net/dataformats/tga/
const Targa = packed struct {
    magic1: u8,
    colormap: u8,
    encoding: u8,
    cmaporig: u16,
    cmaplen: u16,
    cmapent: u8,
    x: u16,
    y: u16,
    width: u16,             // image's height
    height: u16,            // image's width
    bpp: u8,
    pixeltype: u8,
};

var graphics: *GraphicsProtocol = undefined;

fn _plot (x: usize, y: usize, pixel: u32) callconv(.Inline) void {
    @intToPtr(*u32, graphics.mode.frame_buffer_base + 4 * graphics.mode.info.pixels_per_scan_line * y + 4 * x).* = pixel;
}

fn plot (x: usize, y: usize, pixel: u32) void {
    inline for (0 .. 8) |offy| {
        inline for (0 .. 8) |offx| {
            _plot(x * 8 + offx, y * 8 + offy, pixel);
        }
    }
}

var offset: usize = 0;
var running: bool = false;

fn display (_: uefi.Event, _: ?*anyopaque) callconv(.C) void {
    if (running) {
        return;
    }

    running = true;
    defer running = false;

    if (offset < frame.len) {
        var targa: Targa = @ptrCast(* align(1) const Targa, &frame[offset]).*;
        offset += 18;

        if (targa.encoding != 10) {
            @panic("unsupported targa encoding");
        }

        var x: usize = 0;
        var y: usize = 0;
        while (y < targa.height) {
            const header = frame[offset];
            offset += 1;
            var repeat = (header & 0x7F) + 1;
            if (header & 0x80 == 0) {
                while (repeat != 0) : (repeat -= 1) {
                    const pixel = @ptrCast(* align(1) const u24, &frame[offset]).*;
                    plot(x, y, @intCast(u32, pixel));
                    x = (x + 1) % targa.width;
                    y += @boolToInt(x == 0);
                    offset += 3;
                }
            } else {
                const pixel = @ptrCast(* align(1) const u24, &frame[offset]).*;
                while (repeat != 0) : (repeat -= 1) {
                    plot(x, y, @intCast(u32, pixel));
                    x = (x + 1) % targa.width;
                    y += @boolToInt(x == 0);
                }
                offset += 3;
            }
        }
        offset += 26;
    } else {
        offset = 0;
    }
}

fn rickroll () void {
    const boot_services = uefi.system_table.boot_services.?;
    var ptr: usize = 0;
    var status = boot_services.locateProtocol(&GraphicsProtocol.guid, null, @ptrCast(*?*anyopaque, &ptr));
    if (status == .Success) {
        graphics = @intToPtr(*GraphicsProtocol, ptr);
        var event: uefi.Event = undefined;
        status = boot_services.createEvent(0x80000000 | 0x00000200, 16, &display, null, &event);
        if (status != .Success) {
            @panic("failed to create syncing event\r\n");
        }
        status = boot_services.setTimer(event, uefi.tables.TimerDelay.TimerPeriodic, 500000);
        if (status != .Success) {
            @panic("failed to start syncing timer\r\n");
        }
    } else {
        @panic("failed to initialize graphics protocol\r\n");
    }
}

pub fn panic(message: []const u8, stack_trace: ?*builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = stack_trace;
    _ = ret_addr;

    _ = term.stdout.setAttribute(0x0C);
    term.printf("[-] ERROR: {s}\r\nRESTART to try again\r\n", .{ message });

    arch.hang();
}

const std = @import("std");
const builtin = std.builtin;
const arch = @import("arch.zig");
const term = @import("term.zig");
const uefi = std.os.uefi;
const cc = uefi.cc;
const mem = std.mem;
const fmt = std.fmt;
const Http = @import("http.zig").Http;
const HttpServiceBinding = @import("http_service_binding.zig").HttpServiceBinding;
const Status = uefi.Status;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

// MSFROG OS ascii art
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
    "\r\n",
};

fn callback(event: uefi.Event, ctx: ?*anyopaque) callconv(cc) void {
    _ = ctx;
    _ = event;
    term.printf("[!] callback!\r\n", .{});
}

pub fn main() noreturn {
    term.init();

    const boot_services = uefi.system_table.boot_services.?;

    for (logo) |line| {
        term.printf("{s}\r\n", .{line});
    }

    var http_service_binding: *HttpServiceBinding = undefined;
    if (Status.Success != boot_services.locateProtocol(&HttpServiceBinding.guid, null, @ptrCast(&http_service_binding))) {
        @panic("failed to find http service binding");
    }
    term.printf("[+] found http service binding\r\n", .{});

    var http: ?*Http = null;
    var handle: ?uefi.Handle = null;
    if (Status.Success != http_service_binding.createChild(&handle)) {
        @panic("failed to create http service");
    }
    term.printf("[+] created http service\r\n", .{});

    if (Status.Success != boot_services.handleProtocol(handle.?, &Http.guid, @ptrCast(&http))) {
        @panic("failed to bind http service");
    }
    term.printf("[+] http service bound\r\n", .{});

    var access_point = Http.Ipv4AccessPoint{
        .use_default_address = true,
        .local_address = [_]u8{ 0, 0, 0, 0 },
        .local_subnet = [_]u8{ 0, 0, 0, 0 },
        .local_port = 0,
    };
    var config = Http.Config{
        .version = Http.Version.Http11,
        .timeout_millis = 0,
        .is_ipv6 = false,
        .access_point = .{ .ipv4 = &access_point },
    };
    if (Status.Success != http.?.configure(&config)) {
        @panic("failed to configure http");
    }
    term.printf("[+] http configured\r\n", .{});
    term.printf("[+] provided config: \r\n{any}\r\n", .{config});
    config.timeout_millis = 1337;
    config.is_ipv6 = true;
    if (Status.Success != http.?.getModeData(&config)) {
        @panic("failed to get mode data");
    }
    term.printf("[+] confirm config: \r\n{any}\r\n", .{config});

    var req = Http.Request{
        .method = Http.Method.Get,
        .url = L("http://example.com"),
    };
    var header = Http.Header{
        .name = "Host",
        .value = "example.com",
    };
    var message = Http.Message{
        .data = .{ .req = &req },
        .header_count = 1,
        .headers = &header,
        .body_length = 0,
        .body = null,
    };
    var token = Http.Token{
        .event = undefined,
        .status = Status.Success,
        .message = &message,
    };
    if (Status.Success != boot_services.createEvent(uefi.tables.BootServices.event_notify_signal, uefi.tables.BootServices.tpl_callback, &callback, null, &token.event)) {
        @panic("failed to create http callback event");
    }

    var status: Status = undefined;
    while (true) {
        status = http.?.request(&token);
        switch (status) {
            Status.Success => break,
            Status.NoMapping => term.printf("[-] no mapping\r\n", .{}),
            else => {
                term.printf("[!] status: {any}\r\n", .{status});
                @panic("failed to send http request");
            },
        }
    }

    term.printf("poll: {any}\r\n", .{http.?.poll()});

    term.printf("[+] all done\r\n", .{});
    arch.hang();

    // // we can not actually create a socket connection
    // // but we can pretend to by hardcoding the picoctf website
    // var server_buffer = [_]u8{0} ** 128;
    // var port_buffer = [_]u8{0} ** 128;
    // const server_len = term.getline("[+] enter the picoctf server: ", &server_buffer);
    // const port_len = term.getline("[+] enter the picoctf port: ", &port_buffer);

    // const port = fmt.parseInt(u16, port_buffer[0..port_len], 10) catch |err| {
    //     @panic(@errorName(err));
    // };

    // const server = server_buffer[0..server_len];
    // if (!mem.eql(u8, server, "saturn.picoctf.net")) {
    //     term.printf("failed to connect to {s}:{}\r\n", .{ server, port });
    //     @panic("connection error");
    // }

    // term.printf("[+] connecting to {s}:{}\r\n", .{ server, port });
    // term.printf("[+] confirm launch of automated solution of msfroggenerator2\r\n", .{});

    // while (true) {
    //     term.printf("answer yes or no (y/n): ", .{});
    //     const key = @as(u8, @truncate(term.waitForKey().unicode_char));
    //     term.printf("{c}\r\n", .{key});

    //     switch (key) {
    //         'y' => break,
    //         'n' => {
    //             term.printf("Thats too bad...\r\n", .{});
    //             arch.hang();
    //         },
    //         else => {},
    //     }
    // }

    // term.printf("well you asked for it...\r\n", .{});
    // rickroll();

    // arch.hang();
}

// // embed the video file into a u8 buffer
// const frame = @embedFile("video.raw");

// // see: http://paulbourke.net/dataformats/tga/
// const Targa = packed struct {
//     magic1: u8,
//     colormap: u8,
//     encoding: u8,
//     cmaporig: u16,
//     cmaplen: u16,
//     cmapent: u8,
//     x: u16,
//     y: u16,
//     width: u16, // image's height
//     height: u16, // image's width
//     bpp: u8,
//     pixeltype: u8,
// };

// var graphics: *GraphicsProtocol = undefined;

// // hardcode 4 multipliers for 32 bit pixels
// inline fn _plot(x: usize, y: usize, pixel: u32) void {
//     @as(*u32, @ptrFromInt(graphics.mode.frame_buffer_base + 4 * graphics.mode.info.pixels_per_scan_line * y + 4 * x)).* = pixel;
// }

// // plot each pixel as an 8x8 square to make up for resolution downscaling
// fn plot(x: usize, y: usize, pixel: u32) void {
//     inline for (0..8) |offy| {
//         inline for (0..8) |offx| {
//             _plot(x * 8 + offx, y * 8 + offy, pixel);
//         }
//     }
// }

// var offset: usize = 0;
// var running: bool = false;

// // display is called similar to a signal handler is called
// // and subsequent calls can interrupt each other. The running
// // variable ensures that a race does not occur where two display
// // calls are attempting to write to the framebuffer at the same time
// fn display(_: uefi.Event, _: ?*anyopaque) callconv(.C) void {
//     if (running) {
//         return;
//     }

//     running = true;
//     defer running = false;

//     if (offset < frame.len) {
//         var targa: Targa = @as(*align(1) const Targa, @ptrCast(&frame[offset])).*;
//         offset += 18;

//         // ffmpeg outputs RLE targa by default, so the
//         // following code assumes targa RLE encoding.
//         // RLE is indicated by an encoding value of 10
//         if (targa.encoding != 10) {
//             @panic("unsupported targa encoding");
//         }

//         var x: usize = 0;
//         var y: usize = 0;
//         while (y < targa.height) {
//             const header = frame[offset];
//             offset += 1;
//             var repeat = (header & 0x7F) + 1;
//             if (header & 0x80 == 0) {
//                 while (repeat != 0) : (repeat -= 1) {
//                     const pixel = @as(*align(1) const u24, @ptrCast(&frame[offset])).*;
//                     plot(x, y, @as(u32, @intCast(pixel)));
//                     x = (x + 1) % targa.width;
//                     y += @intFromBool(x == 0);
//                     offset += 3;
//                 }
//             } else {
//                 const pixel = @as(*align(1) const u24, @ptrCast(&frame[offset])).*;
//                 while (repeat != 0) : (repeat -= 1) {
//                     plot(x, y, @as(u32, @intCast(pixel)));
//                     x = (x + 1) % targa.width;
//                     y += @intFromBool(x == 0);
//                 }
//                 offset += 3;
//             }
//         }

//         // skip the ending 26 byte footer
//         offset += 26;
//     } else {
//         offset = 0;
//     }
// }

// fn rickroll() void {
//     const boot_services = uefi.system_table.boot_services.?;
//     var status = boot_services.locateProtocol(&GraphicsProtocol.guid, null, @as(*?*anyopaque, @ptrCast(&graphics)));
//     if (status == .Success) {
//         // Instead of rendering each frame and then looping to kill time
//         // setup a timer event using UEFI boot services that will call a function every N ticks.
//         // The 500000 argument in boot_services.setTimer is the number of 100ns ticks between
//         // each timer trigger. The number is an arbitrary choice to make the video seem to run
//         // normally on my computer, and may work as well on others.

//         var event: uefi.Event = undefined;
//         status = boot_services.createEvent(0x80000000 | 0x00000200, 16, &display, null, &event);
//         if (status != .Success) {
//             @panic("failed to create syncing event\r\n");
//         }
//         status = boot_services.setTimer(event, uefi.tables.TimerDelay.TimerPeriodic, 500000);
//         if (status != .Success) {
//             @panic("failed to start syncing timer\r\n");
//         }
//     } else {
//         @panic("failed to initialize graphics protocol\r\n");
//     }
// }

// must provide a panic implementation, similar to how Rust forces you to define
// a panic function to handle errors when using #[no_std]
pub fn panic(message: []const u8, stack_trace: ?*builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = stack_trace;
    _ = ret_addr;

    // see terminal colors here: https://uefi.org/specs/UEFI/2.10/12_Protocols_Console_Support.html#efi-simple-text-output-protocol-setattribute
    _ = term.stdout.setAttribute(0x0C);
    term.printf("[-] ERROR: {s}\r\nRESTART to try again\r\n", .{message});

    arch.hang();
}

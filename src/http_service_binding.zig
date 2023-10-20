const std = @import("std");
const uefi = std.os.uefi;
const Handle = uefi.Handle;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;

pub const HttpServiceBinding = extern struct {
    _create_child: *const fn (*const HttpServiceBinding, *?Handle) callconv(cc) Status,
    _destroy_child: *const fn (*const HttpServiceBinding, Handle) callconv(cc) Status,

    pub fn createChild(self: *const HttpServiceBinding, handle: *?Handle) Status {
        return self._create_child(self, handle);
    }

    pub fn destroyChild(self: *const HttpServiceBinding, handle: Handle) Status {
        return self._destroy_child(self, handle);
    }

    pub const guid align(8) = Guid{
        .time_low = 0xbdc8e6af,
        .time_mid = 0xd9bc,
        .time_high_and_version = 0x4379,
        .clock_seq_high_and_reserved = 0xa7,
        .clock_seq_low = 0x2a,
        .node = [_]u8{ 0xe0, 0xc4, 0xe7, 0x5d, 0xae, 0x1c },
    };
};

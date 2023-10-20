const std = @import("std");
const uefi = std.os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;

pub const Http = extern struct {
    _get_mode_data: *const fn (*const Http, *Config) callconv(cc) Status,
    _configure: *const fn (*const Http, *Config) callconv(cc) Status,
    _request: *const fn (*const Http, *Token) callconv(cc) Status,
    _cancel: *const fn () callconv(cc) Status,
    _response: *const fn () callconv(cc) Status,
    _poll: *const fn (*const Http) callconv(cc) Status,

    pub fn getModeData(self: *const Http, config: *Config) Status {
        return self._get_mode_data(self, config);
    }

    pub fn configure(self: *const Http, config: *Config) Status {
        return self._configure(self, config);
    }

    pub fn request(self: *const Http, token: *Token) Status {
        return self._request(self, token);
    }

    pub fn poll(self: *const Http) Status {
        return self._poll(self);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x7A59B29B,
        .time_mid = 0x910B,
        .time_high_and_version = 0x4171,
        .clock_seq_high_and_reserved = 0x82,
        .clock_seq_low = 0x42,
        .node = [_]u8{ 0xA8, 0x5A, 0x0D, 0xF2, 0x5B, 0x5B },
    };

    pub const Config = extern struct {
        version: Version,
        timeout_millis: u32,
        is_ipv6: bool,
        access_point: AccessPoint,
    };

    pub const Version = enum(u32) {
        Http10,
        Http11,
        Unsupported,
    };

    pub const AccessPoint = extern union {
        ipv4: *Ipv4AccessPoint,
        ipv6: *Ipv6AccessPoint,
    };

    const Ipv4Address = [4]u8;
    const Ipv6Address = [16]u8;

    pub const Ipv4AccessPoint = extern struct {
        use_default_address: bool,
        local_address: Ipv4Address,
        local_subnet: Ipv4Address,
        local_port: u16,
    };

    pub const Ipv6AccessPoint = extern struct {
        local_address: Ipv6Address,
        local_port: u16,
    };

    pub const Token = extern struct {
        event: uefi.Event,
        status: Status,
        message: *Message,
    };

    pub const Message = extern struct {
        data: Data,
        header_count: usize,
        headers: *Header,
        body_length: usize,
        body: ?*anyopaque,
    };

    pub const Header = extern struct {
        name: [*:0]const u8,
        value: [*:0]const u8,
    };

    pub const Data = extern union {
        res: *Response,
        req: *Request,
    };

    pub const Response = extern struct {
        status: StatusCode,
    };

    pub const Request = extern struct {
        method: Method,
        url: [*:0]const u16,
    };

    pub const Method = enum(u32) {
        Get,
        Post,
        Patch,
        Options,
        Connect,
        Head,
        Put,
        Delete,
        Trace,
        Max,
    };

    pub const StatusCode = enum(u32) {
        HTTP_STATUS_UNSUPPORTED_STATUS = 0,
        CONTINUE,
        SWITCHING_PROTOCOLS,
        OK,
        CREATED,
        ACCEPTED,
        NON_AUTHORITATIVE_INFORMATION,
        NO_CONTENT,
        RESET_CONTENT,
        PARTIAL_CONTENT,
        MULTIPLE_CHOICES,
        MOVED_PERMANENTLY,
        FOUND,
        SEE_OTHER,
        NOT_MODIFIED,
        USE_PROXY,
        TEMPORARY_REDIRECT,
        BAD_REQUEST,
        UNAUTHORIZED,
        PAYMENT_REQUIRED,
        FORBIDDEN,
        NOT_FOUND,
        METHOD_NOT_ALLOWED,
        NOT_ACCEPTABLE,
        PROXY_AUTHENTICATION_REQUIRED,
        REQUEST_TIME_OUT,
        CONFLICT,
        GONE,
        LENGTH_REQUIRED,
        PRECONDITION_FAILED,
        REQUEST_ENTITY_TOO_LARGE,
        REQUEST_URI_TOO_LARGE,
        UNSUPPORTED_MEDIA_TYPE,
        REQUESTED_RANGE_NOT_SATISFIED,
        EXPECTATION_FAILED,
        INTERNAL_SERVER_ERROR,
        NOT_IMPLEMENTED,
        BAD_GATEWAY,
        SERVICE_UNAVAILABLE,
        GATEWAY_TIME_OUT,
        HTTP_VERSION_NOT_SUPPORTED,
        PERMANENT_REDIRECT,
    };
};

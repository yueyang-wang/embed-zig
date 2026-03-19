//! Runtime Network Interface Contract
//!
//! Manages network interfaces: add/remove L2 links, IP configuration,
//! DHCP client/server, and interface lifecycle events.
//!
//! Impl must provide:
//!   addIface:        fn (*Impl, IfaceConfig) Error!IfaceFd
//!   removeIface:     fn (*Impl, IfaceFd) void
//!   setIpConfig:     fn (*Impl, IfaceFd, IpConfig) Error!void
//!   getIpConfig:     fn (*const Impl, IfaceFd) ?IpConfig
//!   startDhcpClient: fn (*Impl, IfaceFd, DhcpClientConfig) Error!void
//!   stopDhcpClient:  fn (*Impl, IfaceFd) void
//!   startDhcpServer: fn (*Impl, IfaceFd, DhcpServerConfig) Error!void
//!   stopDhcpServer:  fn (*Impl, IfaceFd) void
//!   getIfaceInfo:    fn (*const Impl, IfaceFd) ?IfaceInfo
//!   ifaceCount:       fn (*const Impl) u16
//!   listIfaces:       fn (*const Impl, []IfaceFd) u16
//!   setDefaultIface:  fn (*Impl, AddressFamily, IfaceFd) Error!void
//!   defaultIface:     fn (*const Impl, AddressFamily) ?IfaceFd
//!   addEventHook:     fn (*Impl, ?*anyopaque, *const fn (?*anyopaque, Event) void) void

const tcpip = @import("tcpip.zig");
const serial = @import("../hal/serial.zig");

pub const Address = tcpip.Address;

pub const AddressFamily = enum { ipv4, ipv6 };

pub const IfaceFd = u32;

pub const IfaceType = enum {
    ethernet,
    wifi,
    ppp,
};

/// Type-erased L2 link — wraps any device that provides read/write/poll
/// (e.g. HAL wifi, modem, or any serial IO device).
///
/// Usage:
///   const link = Link.from(wifi_inst.driver);
///   try netstack.addIface(.{ .iface_type = .wifi, .link = link });
pub const Link = struct {
    ctx: *anyopaque,
    readFn: *const fn (*anyopaque, []u8) serial.ReadError!usize,
    writeFn: *const fn (*anyopaque, []const u8) serial.WriteError!usize,
    pollFn: *const fn (*anyopaque, serial.PollFd, i32) serial.PollFd,

    pub fn from(device: anytype) Link {
        const Ptr = @TypeOf(device);
        const D = @typeInfo(Ptr).pointer.child;
        comptime {
            _ = @as(*const fn (*D, []u8) serial.ReadError!usize, &D.read);
            _ = @as(*const fn (*D, []const u8) serial.WriteError!usize, &D.write);
            _ = @as(*const fn (*D, serial.PollFd, i32) serial.PollFd, &D.poll);
        }
        return .{
            .ctx = @ptrCast(device),
            .readFn = @ptrCast(&D.read),
            .writeFn = @ptrCast(&D.write),
            .pollFn = @ptrCast(&D.poll),
        };
    }

    pub fn read(self: Link, buf: []u8) serial.ReadError!usize {
        return self.readFn(self.ctx, buf);
    }

    pub fn write(self: Link, data: []const u8) serial.WriteError!usize {
        return self.writeFn(self.ctx, data);
    }

    pub fn poll(self: Link, request: serial.PollFd, timeout_ms: i32) serial.PollFd {
        return self.pollFn(self.ctx, request, timeout_ms);
    }
};

pub const IfaceConfig = struct {
    name: []const u8 = "",
    iface_type: IfaceType,
    link: Link,
    mtu: u16 = 1500,
    mac: ?[6]u8 = null,
};

pub const DhcpClientConfig = struct {
    hostname: ?[]const u8 = null,
    timeout_ms: u32 = 30_000,
};

pub const DhcpServerConfig = struct {
    range_start: Address,
    range_end: Address,
    lease_time_s: u32 = 3_600,
    dns: ?Address = null,
};

pub const IpConfig = struct {
    addr: Address,
    netmask: Address,
    gateway: ?Address = null,
    dns_primary: ?Address = null,
    dns_secondary: ?Address = null,
};

pub const IfaceStatus = enum {
    down,
    up,
    dhcp_pending,
};

pub const IfaceInfo = struct {
    iface_type: IfaceType,
    status: IfaceStatus,
    name: [16]u8 = .{0} ** 16,
    name_len: u8 = 0,
    mtu: u16 = 1500,
    mac: ?[6]u8 = null,

    pub fn getName(self: *const IfaceInfo) []const u8 {
        return self.name[0..self.name_len];
    }
};

pub const Event = union(enum) {
    iface_up: IfaceFd,
    iface_down: IfaceFd,
    dhcp_bound: struct { iface: IfaceFd, config: IpConfig },
    dhcp_lost: IfaceFd,
    ppp_up: struct { iface: IfaceFd, config: IpConfig },
    ppp_down: IfaceFd,
    ppp_auth_failed: IfaceFd,
    default_changed: struct { family: AddressFamily, iface: ?IfaceFd },
};

pub const Error = error{
    IfaceFull,
    InvalidIface,
    InvalidConfig,
    DhcpFailed,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, IfaceConfig) Error!IfaceFd, &Impl.addIface);
        _ = @as(*const fn (*Impl, IfaceFd) void, &Impl.removeIface);
        _ = @as(*const fn (*Impl, IfaceFd, IpConfig) Error!void, &Impl.setIpConfig);
        _ = @as(*const fn (*const Impl, IfaceFd) ?IpConfig, &Impl.getIpConfig);
        _ = @as(*const fn (*const Impl, IfaceFd) ?IfaceInfo, &Impl.getIfaceInfo);
        _ = @as(*const fn (*Impl, IfaceFd, DhcpClientConfig) Error!void, &Impl.startDhcpClient);
        _ = @as(*const fn (*Impl, IfaceFd) void, &Impl.stopDhcpClient);
        _ = @as(*const fn (*Impl, IfaceFd, DhcpServerConfig) Error!void, &Impl.startDhcpServer);
        _ = @as(*const fn (*Impl, IfaceFd) void, &Impl.stopDhcpServer);
        _ = @as(*const fn (*const Impl) u16, &Impl.ifaceCount);
        _ = @as(*const fn (*const Impl, []IfaceFd) u16, &Impl.listIfaces);
        _ = @as(*const fn (*Impl, AddressFamily, IfaceFd) Error!void, &Impl.setDefaultIface);
        _ = @as(*const fn (*const Impl, AddressFamily) ?IfaceFd, &Impl.defaultIface);
        _ = @as(*const fn (*Impl, ?*anyopaque, *const fn (?*anyopaque, Event) void) void, &Impl.addEventHook);
    }

    return struct {
        pub const seal: Seal = .{};
        driver: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .driver = driver };
        }

        pub fn deinit(self: *Self) void {
            self.driver = undefined;
        }

        pub fn addIface(self: Self, config: IfaceConfig) Error!IfaceFd {
            return self.driver.addIface(config);
        }

        pub fn removeIface(self: Self, id: IfaceFd) void {
            self.driver.removeIface(id);
        }

        pub fn setIpConfig(self: Self, id: IfaceFd, config: IpConfig) Error!void {
            return self.driver.setIpConfig(id, config);
        }

        pub fn getIpConfig(self: Self, id: IfaceFd) ?IpConfig {
            return self.driver.getIpConfig(id);
        }

        pub fn getIfaceInfo(self: Self, id: IfaceFd) ?IfaceInfo {
            return self.driver.getIfaceInfo(id);
        }

        pub fn startDhcpClient(self: Self, id: IfaceFd, config: DhcpClientConfig) Error!void {
            return self.driver.startDhcpClient(id, config);
        }

        pub fn stopDhcpClient(self: Self, id: IfaceFd) void {
            self.driver.stopDhcpClient(id);
        }

        pub fn startDhcpServer(self: Self, id: IfaceFd, config: DhcpServerConfig) Error!void {
            return self.driver.startDhcpServer(id, config);
        }

        pub fn stopDhcpServer(self: Self, id: IfaceFd) void {
            self.driver.stopDhcpServer(id);
        }

        pub fn ifaceCount(self: Self) u16 {
            return self.driver.ifaceCount();
        }

        /// Fill `buf` with active IfaceFd values; return the count written.
        pub fn listIfaces(self: Self, buf: []IfaceFd) u16 {
            return self.driver.listIfaces(buf);
        }

        pub fn setDefaultIface(self: Self, family: AddressFamily, id: IfaceFd) Error!void {
            return self.driver.setDefaultIface(family, id);
        }

        pub fn defaultIface(self: Self, family: AddressFamily) ?IfaceFd {
            return self.driver.defaultIface(family);
        }

        pub fn addEventHook(self: Self, ctx: ?*anyopaque, call: *const fn (?*anyopaque, Event) void) void {
            self.driver.addEventHook(ctx, call);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}

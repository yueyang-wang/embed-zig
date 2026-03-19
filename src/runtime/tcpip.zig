//! Runtime TCP/IP Contract
//!
//! POSIX-style network abstraction. The driver provides TCP/IP capability;
//! `SockFd` is the resource handle returned by `socket` and passed to all
//! subsequent operations.
//!
//! Impl must provide:
//!   socket:          fn (*Impl, SocketType) Error!SockFd
//!   close:           fn (*Impl, SockFd) void
//!   connect:         fn (*Impl, SockFd, Address) Error!void
//!   bind:            fn (*Impl, SockFd, Address) Error!void
//!   listen:          fn (*Impl, SockFd) Error!void
//!   accept:          fn (*Impl, SockFd) Error!SockFd
//!   send:            fn (*Impl, SockFd, []const u8) Error!usize
//!   recv:            fn (*Impl, SockFd, []u8) Error!usize
//!   sendTo:          fn (*Impl, SockFd, Address, []const u8) Error!usize
//!   recvFrom:        fn (*Impl, SockFd, []u8) Error!RecvFromResult
//!   getBoundPort:    fn (*Impl, SockFd) Error!u16
//!   setRecvTimeout:  fn (*Impl, SockFd, u32) void
//!   setSendTimeout:  fn (*Impl, SockFd, u32) void
//!   setTcpNoDelay:   fn (*Impl, SockFd, bool) void
//!   setNonBlocking:  fn (*Impl, SockFd, bool) Error!void

/// Network address — IPv4 or IPv6 with port.
pub const Address = union(enum) {
    ipv4: struct { addr: [4]u8, port: u16 },
    ipv6: struct { addr: [16]u8, port: u16 },
};

/// Socket type — stream (TCP) or datagram (UDP).
pub const SocketType = enum { stream, dgram };

/// Opaque socket file descriptor.
pub const SockFd = i32;

/// Fixed socket error set for contract signatures.
pub const Error = error{
    CreateFailed,
    BindFailed,
    ConnectFailed,
    SendFailed,
    RecvFailed,
    SetOptionFailed,
    Timeout,
    InvalidAddress,
    Closed,
    ListenFailed,
    AcceptFailed,
};

/// UDP receive result with source endpoint.
pub const RecvFromResult = struct {
    len: usize,
    src: Address,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, SocketType) Error!SockFd, &Impl.socket);
        _ = @as(*const fn (*Impl, SockFd) void, &Impl.close);
        _ = @as(*const fn (*Impl, SockFd, Address) Error!void, &Impl.connect);
        _ = @as(*const fn (*Impl, SockFd, Address) Error!void, &Impl.bind);
        _ = @as(*const fn (*Impl, SockFd) Error!void, &Impl.listen);
        _ = @as(*const fn (*Impl, SockFd) Error!SockFd, &Impl.accept);
        _ = @as(*const fn (*Impl, SockFd, []const u8) Error!usize, &Impl.send);
        _ = @as(*const fn (*Impl, SockFd, []u8) Error!usize, &Impl.recv);
        _ = @as(*const fn (*Impl, SockFd, Address, []const u8) Error!usize, &Impl.sendTo);
        _ = @as(*const fn (*Impl, SockFd, []u8) Error!RecvFromResult, &Impl.recvFrom);
        _ = @as(*const fn (*Impl, SockFd) Error!u16, &Impl.getBoundPort);
        _ = @as(*const fn (*Impl, SockFd, u32) void, &Impl.setRecvTimeout);
        _ = @as(*const fn (*Impl, SockFd, u32) void, &Impl.setSendTimeout);
        _ = @as(*const fn (*Impl, SockFd, bool) void, &Impl.setTcpNoDelay);
        _ = @as(*const fn (*Impl, SockFd, bool) Error!void, &Impl.setNonBlocking);
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

        pub fn socket(self: Self, sock_type: SocketType) Error!SockFd {
            return self.driver.socket(sock_type);
        }

        pub fn close(self: Self, fd: SockFd) void {
            self.driver.close(fd);
        }

        pub fn connect(self: Self, fd: SockFd, addr: Address) Error!void {
            return self.driver.connect(fd, addr);
        }

        pub fn bind(self: Self, fd: SockFd, addr: Address) Error!void {
            return self.driver.bind(fd, addr);
        }

        pub fn listen(self: Self, fd: SockFd) Error!void {
            return self.driver.listen(fd);
        }

        pub fn accept(self: Self, fd: SockFd) Error!SockFd {
            return self.driver.accept(fd);
        }

        pub fn send(self: Self, fd: SockFd, data: []const u8) Error!usize {
            return self.driver.send(fd, data);
        }

        pub fn recv(self: Self, fd: SockFd, buf: []u8) Error!usize {
            return self.driver.recv(fd, buf);
        }

        pub fn sendTo(self: Self, fd: SockFd, addr: Address, data: []const u8) Error!usize {
            return self.driver.sendTo(fd, addr, data);
        }

        pub fn recvFrom(self: Self, fd: SockFd, buf: []u8) Error!RecvFromResult {
            return self.driver.recvFrom(fd, buf);
        }

        pub fn getBoundPort(self: Self, fd: SockFd) Error!u16 {
            return self.driver.getBoundPort(fd);
        }

        pub fn setRecvTimeout(self: Self, fd: SockFd, timeout_ms: u32) void {
            self.driver.setRecvTimeout(fd, timeout_ms);
        }

        pub fn setSendTimeout(self: Self, fd: SockFd, timeout_ms: u32) void {
            self.driver.setSendTimeout(fd, timeout_ms);
        }

        pub fn setTcpNoDelay(self: Self, fd: SockFd, enabled: bool) void {
            self.driver.setTcpNoDelay(fd, enabled);
        }

        pub fn setNonBlocking(self: Self, fd: SockFd, enabled: bool) Error!void {
            return self.driver.setNonBlocking(fd, enabled);
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}

/// Parse IPv4 address from text (e.g. "192.168.1.10").
pub fn parseIpv4(str: []const u8) ?[4]u8 {
    var addr: [4]u8 = undefined;
    var idx: usize = 0;
    var num: u16 = 0;
    var dots: u8 = 0;
    var has_digit_in_segment = false;

    if (str.len == 0) return null;

    for (str) |ch| {
        if (ch >= '0' and ch <= '9') {
            num = num * 10 + (ch - '0');
            if (num > 255) return null;
            has_digit_in_segment = true;
        } else if (ch == '.') {
            if (!has_digit_in_segment) return null;
            if (idx >= 3) return null;
            addr[idx] = @intCast(num);
            idx += 1;
            num = 0;
            dots += 1;
            has_digit_in_segment = false;
        } else {
            return null;
        }
    }

    if (dots != 3 or idx != 3 or !has_digit_in_segment) return null;
    addr[3] = @intCast(num);
    return addr;
}

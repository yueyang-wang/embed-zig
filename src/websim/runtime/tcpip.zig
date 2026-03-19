const std = @import("std");
const embed = @import("../../mod.zig");
const tcpip_mod = embed.runtime.tcpip;

pub const TcpIp = struct {
    pub fn socket(_: *TcpIp, sock_type: tcpip_mod.SocketType) tcpip_mod.Error!tcpip_mod.SockFd {
        const posix_type: u32 = switch (sock_type) {
            .stream => std.posix.SOCK.STREAM,
            .dgram => std.posix.SOCK.DGRAM,
        };
        const proto: u32 = switch (sock_type) {
            .stream => std.posix.IPPROTO.TCP,
            .dgram => std.posix.IPPROTO.UDP,
        };
        const fd = std.posix.socket(std.posix.AF.INET, posix_type, proto) catch {
            return error.CreateFailed;
        };
        return @intCast(fd);
    }

    pub fn close(_: *TcpIp, fd: tcpip_mod.SockFd) void {
        std.posix.close(@intCast(fd));
    }

    pub fn connect(_: *TcpIp, fd: tcpip_mod.SockFd, addr: tcpip_mod.Address) tcpip_mod.Error!void {
        var net_addr = toStdAddress(addr);
        std.posix.connect(@intCast(fd), &net_addr.any, net_addr.getOsSockLen()) catch |err| switch (err) {
            error.ConnectionTimedOut, error.WouldBlock => return error.Timeout,
            else => return error.ConnectFailed,
        };
    }

    pub fn bind(_: *TcpIp, fd: tcpip_mod.SockFd, addr: tcpip_mod.Address) tcpip_mod.Error!void {
        var net_addr = toStdAddress(addr);
        std.posix.bind(@intCast(fd), &net_addr.any, net_addr.getOsSockLen()) catch {
            return error.BindFailed;
        };
    }

    pub fn listen(_: *TcpIp, fd: tcpip_mod.SockFd) tcpip_mod.Error!void {
        std.posix.listen(@intCast(fd), 128) catch {
            return error.ListenFailed;
        };
    }

    pub fn accept(_: *TcpIp, fd: tcpip_mod.SockFd) tcpip_mod.Error!tcpip_mod.SockFd {
        var peer: std.net.Address = undefined;
        var peer_len: std.posix.socklen_t = @sizeOf(std.net.Address);
        const client_fd = std.posix.accept(@intCast(fd), &peer.any, &peer_len, 0) catch {
            return error.AcceptFailed;
        };
        return @intCast(client_fd);
    }

    pub fn send(_: *TcpIp, fd: tcpip_mod.SockFd, data: []const u8) tcpip_mod.Error!usize {
        return std.posix.send(@intCast(fd), data, 0) catch |err| switch (err) {
            error.WouldBlock => error.Timeout,
            else => error.SendFailed,
        };
    }

    pub fn recv(_: *TcpIp, fd: tcpip_mod.SockFd, buf: []u8) tcpip_mod.Error!usize {
        const n = std.posix.recv(@intCast(fd), buf, 0) catch |err| switch (err) {
            error.WouldBlock, error.ConnectionTimedOut => return error.Timeout,
            else => return error.RecvFailed,
        };
        if (n == 0) return error.Closed;
        return n;
    }

    pub fn sendTo(_: *TcpIp, fd: tcpip_mod.SockFd, addr: tcpip_mod.Address, data: []const u8) tcpip_mod.Error!usize {
        var net_addr = toStdAddress(addr);
        return std.posix.sendto(@intCast(fd), data, 0, &net_addr.any, net_addr.getOsSockLen()) catch |err| switch (err) {
            error.WouldBlock => error.Timeout,
            else => error.SendFailed,
        };
    }

    pub fn recvFrom(_: *TcpIp, fd: tcpip_mod.SockFd, buf: []u8) tcpip_mod.Error!tcpip_mod.RecvFromResult {
        var src: std.net.Address = undefined;
        var src_len: std.posix.socklen_t = @sizeOf(std.net.Address);
        const n = std.posix.recvfrom(@intCast(fd), buf, 0, &src.any, &src_len) catch |err| switch (err) {
            error.WouldBlock, error.ConnectionTimedOut => return error.Timeout,
            else => return error.RecvFailed,
        };
        return .{
            .len = n,
            .src = fromStdAddress(src) orelse return error.InvalidAddress,
        };
    }

    pub fn getBoundPort(_: *TcpIp, fd: tcpip_mod.SockFd) tcpip_mod.Error!u16 {
        var local: std.net.Address = undefined;
        var local_len: std.posix.socklen_t = @sizeOf(std.net.Address);
        std.posix.getsockname(@intCast(fd), &local.any, &local_len) catch {
            return error.BindFailed;
        };
        return local.getPort();
    }

    pub fn setRecvTimeout(_: *TcpIp, fd: tcpip_mod.SockFd, timeout_ms: u32) void {
        const tv = msToTimeval(timeout_ms);
        std.posix.setsockopt(@intCast(fd), std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&tv)) catch {};
    }

    pub fn setSendTimeout(_: *TcpIp, fd: tcpip_mod.SockFd, timeout_ms: u32) void {
        const tv = msToTimeval(timeout_ms);
        std.posix.setsockopt(@intCast(fd), std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.asBytes(&tv)) catch {};
    }

    pub fn setTcpNoDelay(_: *TcpIp, fd: tcpip_mod.SockFd, enabled: bool) void {
        const v: i32 = if (enabled) 1 else 0;
        std.posix.setsockopt(@intCast(fd), std.posix.IPPROTO.TCP, std.posix.TCP.NODELAY, std.mem.asBytes(&v)) catch {};
    }

    pub fn setNonBlocking(_: *TcpIp, fd: tcpip_mod.SockFd, enabled: bool) tcpip_mod.Error!void {
        var fl_flags = std.posix.fcntl(@intCast(fd), std.posix.F.GETFL, 0) catch return error.SetOptionFailed;
        const mask: usize = @as(usize, 1) << @bitOffsetOf(std.posix.O, "NONBLOCK");
        if (enabled) {
            fl_flags |= mask;
        } else {
            fl_flags &= ~mask;
        }
        _ = std.posix.fcntl(@intCast(fd), std.posix.F.SETFL, fl_flags) catch return error.SetOptionFailed;
    }

    fn toStdAddress(addr: tcpip_mod.Address) std.net.Address {
        return switch (addr) {
            .ipv4 => |v| std.net.Address.initIp4(v.addr, v.port),
            .ipv6 => |v| std.net.Address.initIp6(v.addr, v.port, 0, 0),
        };
    }

    fn fromStdAddress(addr: std.net.Address) ?tcpip_mod.Address {
        if (addr.any.family == std.posix.AF.INET) {
            const ip_ptr: *const [4]u8 = @ptrCast(&addr.in.sa.addr);
            return .{ .ipv4 = .{ .addr = ip_ptr.*, .port = addr.getPort() } };
        } else if (addr.any.family == std.posix.AF.INET6) {
            const ip_ptr: *const [16]u8 = @ptrCast(&addr.in6.sa.addr);
            return .{ .ipv6 = .{ .addr = ip_ptr.*, .port = addr.getPort() } };
        }
        return null;
    }

    fn msToTimeval(ms: u32) std.posix.timeval {
        return .{
            .sec = @intCast(ms / 1000),
            .usec = @intCast((ms % 1000) * 1000),
        };
    }
};

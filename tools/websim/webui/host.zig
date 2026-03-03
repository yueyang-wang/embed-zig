const std = @import("std");
const engine_mod = @import("../core/engine.zig");
const protocol = @import("../core/protocol.zig");

const websocket_guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

const default_index = @embedFile("default/index.html");
const default_app_js = @embedFile("default/app.js");
const default_style = @embedFile("default/style.css");

pub const Options = struct {
    host: [4]u8 = .{ 127, 0, 0, 1 },
    port: u16 = 8080,
    style_dir: ?[]const u8 = null,
};

const WsFrameError = error{
    ConnectionClosed,
    FrameTooLarge,
    FragmentedFrameUnsupported,
    InvalidFrame,
};

const WsFrame = struct {
    opcode: u8,
    payload: []u8,
};

pub fn run(allocator: std.mem.Allocator, options: Options) !void {
    const listen_fd = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);
    defer std.posix.close(listen_fd);

    const reuse_addr: i32 = 1;
    std.posix.setsockopt(listen_fd, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, std.mem.asBytes(&reuse_addr)) catch {};

    var address = std.net.Address.initIp4(options.host, options.port);
    try std.posix.bind(listen_fd, &address.any, address.getOsSockLen());
    try std.posix.listen(listen_fd, 128);

    const host_display = try std.fmt.allocPrint(allocator, "{d}.{d}.{d}.{d}", .{ options.host[0], options.host[1], options.host[2], options.host[3] });
    defer allocator.free(host_display);

    std.debug.print("[websim:serve] listening on http://{s}:{d}\n", .{ host_display, options.port });

    while (true) {
        const client_fd = std.posix.accept(listen_fd, null, null, 0) catch |err| switch (err) {
            error.WouldBlock, error.ConnectionAborted => continue,
            else => return err,
        };
        defer std.posix.close(client_fd);

        handleConnection(allocator, client_fd, options) catch |err| {
            std.debug.print("[websim:serve] connection error: {s}\n", .{@errorName(err)});
        };
    }
}

fn handleConnection(allocator: std.mem.Allocator, client_fd: std.posix.fd_t, options: Options) !void {
    var request_buf: [16 * 1024]u8 = undefined;
    const request = try readHttpRequest(client_fd, &request_buf);
    const path = try parseRequestPath(request);

    if (std.mem.eql(u8, path, "/ws") and isWebSocketUpgrade(request)) {
        try handleWebSocketSession(allocator, client_fd, request);
        return;
    }

    try serveStatic(allocator, client_fd, path, options);
}

fn serveStatic(allocator: std.mem.Allocator, client_fd: std.posix.fd_t, path: []const u8, options: Options) !void {
    if (std.mem.eql(u8, path, "/") or std.mem.eql(u8, path, "/index.html")) {
        try sendHttpResponse(client_fd, "200 OK", "text/html; charset=utf-8", default_index);
        return;
    }

    if (std.mem.eql(u8, path, "/app.js")) {
        try sendHttpResponse(client_fd, "200 OK", "application/javascript; charset=utf-8", default_app_js);
        return;
    }

    if (std.mem.eql(u8, path, "/style.css")) {
        if (options.style_dir) |style_dir| {
            const style_path = try std.fs.path.join(allocator, &[_][]const u8{ style_dir, "style.css" });
            defer allocator.free(style_path);

            const custom = std.fs.cwd().readFileAlloc(allocator, style_path, 512 * 1024) catch null;
            if (custom) |style_text| {
                defer allocator.free(style_text);
                try sendHttpResponse(client_fd, "200 OK", "text/css; charset=utf-8", style_text);
                return;
            }
        }

        try sendHttpResponse(client_fd, "200 OK", "text/css; charset=utf-8", default_style);
        return;
    }

    try sendHttpResponse(client_fd, "404 Not Found", "text/plain; charset=utf-8", "not found\n");
}

fn handleWebSocketSession(allocator: std.mem.Allocator, client_fd: std.posix.fd_t, request: []const u8) !void {
    const sec_key = headerValue(request, "Sec-WebSocket-Key") orelse {
        try sendHttpResponse(client_fd, "400 Bad Request", "text/plain; charset=utf-8", "missing websocket key\n");
        return;
    };

    var sha1 = std.crypto.hash.Sha1.init(.{});
    sha1.update(sec_key);
    sha1.update(websocket_guid);
    var digest: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    sha1.final(&digest);

    var accept_buf: [64]u8 = undefined;
    const sec_accept = std.base64.standard.Encoder.encode(accept_buf[0..], digest[0..]);

    var handshake_buf: [256]u8 = undefined;
    const handshake = try std.fmt.bufPrint(
        &handshake_buf,
        "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {s}\r\n\r\n",
        .{sec_accept},
    );
    try writeAll(client_fd, handshake);

    var engine = try engine_mod.Engine.init(allocator);
    defer engine.deinit();

    var frame_payload_buf: [8 * 1024]u8 = undefined;
    while (true) {
        const frame = readWebSocketFrame(client_fd, &frame_payload_buf) catch |err| switch (err) {
            error.ConnectionClosed => break,
            else => return err,
        };

        switch (frame.opcode) {
            0x8 => {
                try sendCloseFrame(client_fd);
                break;
            },
            0x1 => {
                defer engine.resetCycle();

                const inbound = protocol.parseInlineMessage(engine.cycleAllocator(), frame.payload) catch |parse_err| {
                    try sendErrorFrame(client_fd, 0, @errorName(parse_err));
                    continue;
                };

                engine.applySend(inbound) catch |apply_err| {
                    try sendErrorFrame(client_fd, inbound.t, @errorName(apply_err));
                    continue;
                };

                while (engine.popOutbound()) |outbound| {
                    var text_buf: [1024]u8 = undefined;
                    var fbs = std.io.fixedBufferStream(&text_buf);
                    protocol.formatMessage(outbound, fbs.writer()) catch {
                        try sendErrorFrame(client_fd, outbound.t, "format_error");
                        continue;
                    };
                    try sendTextFrame(client_fd, fbs.getWritten());
                }
            },
            else => {
                // ignore ping/pong/binary for this minimal host
            },
        }
    }
}

fn sendErrorFrame(client_fd: std.posix.fd_t, t: u64, reason: []const u8) !void {
    var buf: [512]u8 = undefined;
    const payload = try std.fmt.bufPrint(
        &buf,
        "{{ op: \"err\", t: {}, dev: \"sys\", v: {{ reason: \"{s}\" }} }}",
        .{ t, reason },
    );
    try sendTextFrame(client_fd, payload);
}

fn readHttpRequest(client_fd: std.posix.fd_t, buf: []u8) ![]const u8 {
    var used: usize = 0;
    while (used < buf.len) {
        const n = try std.posix.recv(client_fd, buf[used..], 0);
        if (n == 0) return error.ConnectionClosed;
        used += n;

        if (std.mem.indexOf(u8, buf[0..used], "\r\n\r\n") != null) {
            return buf[0..used];
        }
    }
    return error.MessageTooLong;
}

fn parseRequestPath(request: []const u8) ![]const u8 {
    const line_end = std.mem.indexOf(u8, request, "\r\n") orelse return error.BadRequest;
    const request_line = request[0..line_end];
    if (!std.mem.startsWith(u8, request_line, "GET ")) return error.BadRequest;
    const rest = request_line[4..];
    const path_end = std.mem.indexOfScalar(u8, rest, ' ') orelse return error.BadRequest;
    return rest[0..path_end];
}

fn isWebSocketUpgrade(request: []const u8) bool {
    const upgrade = headerValue(request, "Upgrade") orelse return false;
    const connection = headerValue(request, "Connection") orelse return false;
    return std.ascii.eqlIgnoreCase(upgrade, "websocket") and
        containsTokenIgnoreCase(connection, "Upgrade");
}

fn headerValue(request: []const u8, target_key: []const u8) ?[]const u8 {
    var lines = std.mem.splitSequence(u8, request, "\r\n");
    _ = lines.next();
    while (lines.next()) |line| {
        if (line.len == 0) break;
        const split = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = std.mem.trim(u8, line[0..split], " \t");
        if (!std.ascii.eqlIgnoreCase(key, target_key)) continue;
        return std.mem.trim(u8, line[split + 1 ..], " \t");
    }
    return null;
}

fn containsTokenIgnoreCase(header_value: []const u8, token: []const u8) bool {
    var parts = std.mem.splitScalar(u8, header_value, ',');
    while (parts.next()) |part| {
        if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, part, " \t"), token)) {
            return true;
        }
    }
    return false;
}

fn sendHttpResponse(client_fd: std.posix.fd_t, status: []const u8, content_type: []const u8, body: []const u8) !void {
    var header_buf: [256]u8 = undefined;
    const header = try std.fmt.bufPrint(
        &header_buf,
        "HTTP/1.1 {s}\r\nContent-Type: {s}\r\nContent-Length: {}\r\nConnection: close\r\nCache-Control: no-cache\r\n\r\n",
        .{ status, content_type, body.len },
    );
    try writeAll(client_fd, header);
    try writeAll(client_fd, body);
}

fn readWebSocketFrame(client_fd: std.posix.fd_t, payload_buf: []u8) !WsFrame {
    var h: [2]u8 = undefined;
    try readExact(client_fd, &h);

    const fin = (h[0] & 0x80) != 0;
    if (!fin) return error.FragmentedFrameUnsupported;

    const opcode = h[0] & 0x0f;
    const masked = (h[1] & 0x80) != 0;

    var payload_len: usize = h[1] & 0x7f;
    if (payload_len == 126) {
        var ext: [2]u8 = undefined;
        try readExact(client_fd, &ext);
        payload_len = (@as(usize, ext[0]) << 8) | @as(usize, ext[1]);
    } else if (payload_len == 127) {
        var ext: [8]u8 = undefined;
        try readExact(client_fd, &ext);
        const len_u64 =
            (@as(u64, ext[0]) << 56) | (@as(u64, ext[1]) << 48) | (@as(u64, ext[2]) << 40) | (@as(u64, ext[3]) << 32) |
            (@as(u64, ext[4]) << 24) | (@as(u64, ext[5]) << 16) | (@as(u64, ext[6]) << 8) | @as(u64, ext[7]);
        if (len_u64 > payload_buf.len) return error.FrameTooLarge;
        payload_len = @intCast(len_u64);
    }

    if (payload_len > payload_buf.len) return error.FrameTooLarge;

    var mask_key: [4]u8 = .{ 0, 0, 0, 0 };
    if (masked) {
        try readExact(client_fd, &mask_key);
    }

    try readExact(client_fd, payload_buf[0..payload_len]);

    if (masked) {
        for (payload_buf[0..payload_len], 0..) |*byte, idx| {
            byte.* ^= mask_key[idx % 4];
        }
    }

    return .{ .opcode = opcode, .payload = payload_buf[0..payload_len] };
}

fn sendTextFrame(client_fd: std.posix.fd_t, payload: []const u8) !void {
    var header: [10]u8 = undefined;
    var h_len: usize = 0;
    header[h_len] = 0x81;
    h_len += 1;

    if (payload.len <= 125) {
        header[h_len] = @intCast(payload.len);
        h_len += 1;
    } else if (payload.len <= std.math.maxInt(u16)) {
        header[h_len] = 126;
        h_len += 1;
        const len16: u16 = @intCast(payload.len);
        header[h_len] = @intCast((len16 >> 8) & 0xff);
        header[h_len + 1] = @intCast(len16 & 0xff);
        h_len += 2;
    } else {
        return error.FrameTooLarge;
    }

    try writeAll(client_fd, header[0..h_len]);
    try writeAll(client_fd, payload);
}

fn sendCloseFrame(client_fd: std.posix.fd_t) !void {
    const close_bytes = [_]u8{ 0x88, 0x00 };
    try writeAll(client_fd, &close_bytes);
}

fn readExact(client_fd: std.posix.fd_t, out: []u8) !void {
    var done: usize = 0;
    while (done < out.len) {
        const n = try std.posix.recv(client_fd, out[done..], 0);
        if (n == 0) return error.ConnectionClosed;
        done += n;
    }
}

fn writeAll(client_fd: std.posix.fd_t, data: []const u8) !void {
    var sent: usize = 0;
    while (sent < data.len) {
        const n = try std.posix.send(client_fd, data[sent..], 0);
        if (n == 0) return error.ConnectionClosed;
        sent += n;
    }
}

test "parse request path" {
    const req = "GET /ws HTTP/1.1\r\nHost: localhost:8080\r\n\r\n";
    const path = try parseRequestPath(req);
    try std.testing.expectEqualStrings("/ws", path);
}

test "header value lookup is case-insensitive" {
    const req =
        "GET / HTTP/1.1\r\n" ++
        "host: localhost\r\n" ++
        "Upgrade: websocket\r\n" ++
        "Connection: Upgrade\r\n\r\n";
    const upgrade = headerValue(req, "upgrade") orelse return error.ExpectedHeader;
    try std.testing.expect(std.ascii.eqlIgnoreCase(upgrade, "websocket"));
    try std.testing.expect(isWebSocketUpgrade(req));
}

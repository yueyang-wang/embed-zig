const std = @import("std");
const testing = std.testing;
const module = @import("embed").pkg.net.http.response;
const Response = module.Response;
const statusText = module.statusText;
const mem = std.mem;
const request = module.request;
const containsCrlf = module.containsCrlf;
const appendBuf = module.appendBuf;
const writeStatusCode = module.writeStatusCode;
const TestWriter = module.TestWriter;
test "200 OK with body" {
    var tw = TestWriter{};
    var write_buf: [512]u8 = undefined;
    var resp = Response{
        .write_buf = &write_buf,
        .write_fn = TestWriter.writeFn,
        .write_ctx = @ptrCast(&tw),
    };

    resp.send("Hello, World!");

    const out = tw.output();
    try testing.expect(mem.startsWith(u8, out, "HTTP/1.1 200 OK\r\n"));
    try testing.expect(mem.indexOf(u8, out, "Content-Length: 13\r\n") != null);
    try testing.expect(mem.endsWith(u8, out, "Hello, World!"));
}

test "JSON response" {
    var tw = TestWriter{};
    var write_buf: [512]u8 = undefined;
    var resp = Response{
        .write_buf = &write_buf,
        .write_fn = TestWriter.writeFn,
        .write_ctx = @ptrCast(&tw),
    };

    resp.json("{\"status\":\"ok\"}");

    const out = tw.output();
    try testing.expect(mem.indexOf(u8, out, "Content-Type: application/json\r\n") != null);
    try testing.expect(mem.endsWith(u8, out, "{\"status\":\"ok\"}"));
}

test "404 sendStatus" {
    var tw = TestWriter{};
    var write_buf: [512]u8 = undefined;
    var resp = Response{
        .write_buf = &write_buf,
        .write_fn = TestWriter.writeFn,
        .write_ctx = @ptrCast(&tw),
    };

    resp.sendStatus(404);

    const out = tw.output();
    try testing.expect(mem.startsWith(u8, out, "HTTP/1.1 404 Not Found\r\n"));
    try testing.expect(mem.indexOf(u8, out, "Content-Length: 0\r\n") != null);
}

test "multiple headers" {
    var tw = TestWriter{};
    var write_buf: [512]u8 = undefined;
    var resp = Response{
        .write_buf = &write_buf,
        .write_fn = TestWriter.writeFn,
        .write_ctx = @ptrCast(&tw),
    };

    _ = resp.setHeader("X-Request-Id", "abc123").setHeader("Cache-Control", "no-cache");
    resp.send("ok");

    const out = tw.output();
    try testing.expect(mem.indexOf(u8, out, "X-Request-Id: abc123\r\n") != null);
    try testing.expect(mem.indexOf(u8, out, "Cache-Control: no-cache\r\n") != null);
    try testing.expect(mem.endsWith(u8, out, "ok"));
}

test "CRLF injection rejected" {
    var tw = TestWriter{};
    var write_buf: [512]u8 = undefined;
    var resp = Response{
        .write_buf = &write_buf,
        .write_fn = TestWriter.writeFn,
        .write_ctx = @ptrCast(&tw),
    };

    _ = resp.setHeader("X-Bad", "value\r\nInjected: yes");
    resp.send("ok");

    const out = tw.output();
    try testing.expect(mem.indexOf(u8, out, "Injected") == null);
}

test "statusText known codes" {
    try testing.expectEqualStrings("OK", statusText(200));
    try testing.expectEqualStrings("Not Found", statusText(404));
    try testing.expectEqualStrings("Internal Server Error", statusText(500));
    try testing.expectEqualStrings("Unknown", statusText(999));
}

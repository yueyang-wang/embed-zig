const std = @import("std");
const testing = std.testing;
const embed = @import("embed");
const module = embed.pkg.net.http.static;
const EmbeddedFile = module.EmbeddedFile;
const serveEmbedded = module.serveEmbedded;
const mimeFromPath = module.mimeFromPath;
const mem = std.mem;
const request_mod = embed.pkg.net.http.request;
const response_mod = embed.pkg.net.http.response;
const router_mod = embed.pkg.net.http.router;
const Request = request_mod.Request;
const Response = response_mod.Response;
const endsWith = module.endsWith;
const TestWriter = module.TestWriter;
const test_files = module.test_files;
test "embedded file hit" {
    var tw = TestWriter{};
    var write_buf: [512]u8 = undefined;
    var resp = Response{
        .write_buf = &write_buf,
        .write_fn = TestWriter.writeFn,
        .write_ctx = @ptrCast(&tw),
    };
    var req = Request{
        .method = .GET,
        .path = "/static/app.js",
        .query = null,
        .version = "HTTP/1.1",
        .header_bytes = "",
        .body = null,
        .content_length = 0,
    };

    const handler = serveEmbedded(&test_files);
    handler(&req, &resp);

    const out = tw.output();
    try testing.expect(mem.indexOf(u8, out, "Content-Type: application/javascript\r\n") != null);
    try testing.expect(mem.endsWith(u8, out, "console.log('hello');"));
}

test "embedded file 404" {
    var tw = TestWriter{};
    var write_buf: [512]u8 = undefined;
    var resp = Response{
        .write_buf = &write_buf,
        .write_fn = TestWriter.writeFn,
        .write_ctx = @ptrCast(&tw),
    };
    var req = Request{
        .method = .GET,
        .path = "/static/nonexistent.js",
        .query = null,
        .version = "HTTP/1.1",
        .header_bytes = "",
        .body = null,
        .content_length = 0,
    };

    const handler = serveEmbedded(&test_files);
    handler(&req, &resp);

    const out = tw.output();
    try testing.expect(mem.startsWith(u8, out, "HTTP/1.1 404 Not Found\r\n"));
}

test "mimeFromPath" {
    try testing.expectEqualStrings("text/html", mimeFromPath("/index.html"));
    try testing.expectEqualStrings("text/css", mimeFromPath("/style.css"));
    try testing.expectEqualStrings("application/javascript", mimeFromPath("/app.js"));
    try testing.expectEqualStrings("application/json", mimeFromPath("/data.json"));
    try testing.expectEqualStrings("image/png", mimeFromPath("/logo.png"));
    try testing.expectEqualStrings("application/octet-stream", mimeFromPath("/unknown.xyz"));
}

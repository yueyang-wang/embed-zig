const std = @import("std");
const testing = std.testing;
const module = @import("embed").pkg.net.http.router;
const Handler = module.Handler;
const MatchType = module.MatchType;
const Route = module.Route;
const get = module.get;
const post = module.post;
const put = module.put;
const delete = module.delete;
const prefix = module.prefix;
const MatchResult = module.MatchResult;
const RouteMatch = module.RouteMatch;
const match = module.match;
const mem = module.mem;
const request_mod = module.request_mod;
const response_mod = module.response_mod;
const Request = module.Request;
const Response = module.Response;
const Method = module.Method;
const dummyHandler = module.dummyHandler;
const dummyHandler2 = module.dummyHandler2;

test "exact match" {
    const routes = [_]Route{
        get("/api/status", dummyHandler),
        post("/api/data", dummyHandler2),
    };

    const m = match(&routes, .GET, "/api/status");
    try testing.expectEqual(MatchResult.found, m.result);
    try testing.expect(m.handler != null);
}

test "prefix match" {
    const routes = [_]Route{
        prefix("/static/", dummyHandler),
    };

    const m1 = match(&routes, .GET, "/static/app.js");
    try testing.expectEqual(MatchResult.found, m1.result);

    const m2 = match(&routes, .GET, "/static/css/style.css");
    try testing.expectEqual(MatchResult.found, m2.result);

    const m3 = match(&routes, .GET, "/api/other");
    try testing.expectEqual(MatchResult.not_found, m3.result);
}

test "prefix matches any method" {
    const routes = [_]Route{
        prefix("/api/", dummyHandler),
    };

    try testing.expectEqual(MatchResult.found, match(&routes, .GET, "/api/foo").result);
    try testing.expectEqual(MatchResult.found, match(&routes, .POST, "/api/foo").result);
    try testing.expectEqual(MatchResult.found, match(&routes, .PUT, "/api/foo").result);
    try testing.expectEqual(MatchResult.found, match(&routes, .DELETE, "/api/foo").result);
}

test "404 no match" {
    const routes = [_]Route{
        get("/api/status", dummyHandler),
    };

    const m = match(&routes, .GET, "/unknown");
    try testing.expectEqual(MatchResult.not_found, m.result);
    try testing.expect(m.handler == null);
}

test "method mismatch — 405" {
    const routes = [_]Route{
        get("/api/status", dummyHandler),
    };

    const m = match(&routes, .POST, "/api/status");
    try testing.expectEqual(MatchResult.method_not_allowed, m.result);
    try testing.expect(m.handler == null);
}

const std = @import("std");

pub const Scalar = union(enum) {
    string: []const u8,
    int: i64,
    boolean: bool,
};

pub const Field = struct {
    key: []const u8,
    value: Scalar,
};

pub const Payload = struct {
    fields: []const Field,

    pub fn get(self: Payload, key: []const u8) ?Scalar {
        for (self.fields) |field| {
            if (std.mem.eql(u8, field.key, key)) {
                return field.value;
            }
        }
        return null;
    }

    pub fn getString(self: Payload, key: []const u8) ?[]const u8 {
        const value = self.get(key) orelse return null;
        return switch (value) {
            .string => |s| s,
            else => null,
        };
    }

    pub fn getInt(self: Payload, key: []const u8) ?i64 {
        const value = self.get(key) orelse return null;
        return switch (value) {
            .int => |n| n,
            else => null,
        };
    }

    pub fn getBool(self: Payload, key: []const u8) ?bool {
        const value = self.get(key) orelse return null;
        return switch (value) {
            .boolean => |b| b,
            else => null,
        };
    }
};

pub const Message = struct {
    op: []const u8,
    t: u64,
    dev: []const u8,
    v: Payload,
};

pub const ParseError = std.mem.Allocator.Error || error{
    UnexpectedEof,
    UnexpectedToken,
    InvalidIdentifier,
    InvalidString,
    InvalidNumber,
    InvalidBoolean,
    InvalidTopLevelValue,
    UnknownTopLevelField,
    MissingRequiredField,
    UnsupportedPayloadValue,
    NegativeTimestamp,
};

const Parser = struct {
    input: []const u8,
    index: usize = 0,

    fn skipSpaces(self: *Parser) void {
        while (self.index < self.input.len) {
            const ch = self.input[self.index];
            if (ch == ' ' or ch == '\t' or ch == '\r' or ch == '\n') {
                self.index += 1;
                continue;
            }
            break;
        }
    }

    fn expectByte(self: *Parser, expected: u8) ParseError!void {
        self.skipSpaces();
        if (self.index >= self.input.len) return error.UnexpectedEof;
        if (self.input[self.index] != expected) return error.UnexpectedToken;
        self.index += 1;
    }

    fn parseIdentifier(self: *Parser) ParseError![]const u8 {
        self.skipSpaces();
        if (self.index >= self.input.len) return error.UnexpectedEof;

        const start = self.index;
        const first = self.input[self.index];
        if (!isIdentStart(first)) return error.InvalidIdentifier;
        self.index += 1;

        while (self.index < self.input.len and isIdentBody(self.input[self.index])) {
            self.index += 1;
        }

        return self.input[start..self.index];
    }

    fn parseString(self: *Parser) ParseError![]const u8 {
        self.skipSpaces();
        if (self.index >= self.input.len) return error.UnexpectedEof;
        if (self.input[self.index] != '"') return error.InvalidString;

        self.index += 1;
        const start = self.index;

        while (self.index < self.input.len) : (self.index += 1) {
            const ch = self.input[self.index];
            if (ch == '\\') {
                if (self.index + 1 >= self.input.len) return error.InvalidString;
                self.index += 1;
                continue;
            }
            if (ch == '"') {
                const slice = self.input[start..self.index];
                self.index += 1;
                return slice;
            }
        }

        return error.InvalidString;
    }

    fn parseInt(self: *Parser) ParseError!i64 {
        self.skipSpaces();
        if (self.index >= self.input.len) return error.UnexpectedEof;

        const start = self.index;
        if (self.input[self.index] == '-') {
            self.index += 1;
        }

        var digit_count: usize = 0;
        while (self.index < self.input.len and std.ascii.isDigit(self.input[self.index])) : (self.index += 1) {
            digit_count += 1;
        }

        if (digit_count == 0) return error.InvalidNumber;

        return std.fmt.parseInt(i64, self.input[start..self.index], 10) catch return error.InvalidNumber;
    }

    fn parseBool(self: *Parser) ParseError!bool {
        self.skipSpaces();
        if (self.index >= self.input.len) return error.UnexpectedEof;

        const remain = self.input[self.index..];
        if (std.mem.startsWith(u8, remain, "true")) {
            self.index += 4;
            return true;
        }
        if (std.mem.startsWith(u8, remain, "false")) {
            self.index += 5;
            return false;
        }
        return error.InvalidBoolean;
    }

    fn parseScalar(self: *Parser) ParseError!Scalar {
        self.skipSpaces();
        if (self.index >= self.input.len) return error.UnexpectedEof;

        const ch = self.input[self.index];
        if (ch == '"') {
            return .{ .string = try self.parseString() };
        }
        if (ch == '-' or std.ascii.isDigit(ch)) {
            return .{ .int = try self.parseInt() };
        }
        if (ch == 't' or ch == 'f') {
            return .{ .boolean = try self.parseBool() };
        }
        return error.UnsupportedPayloadValue;
    }

    fn parsePayload(self: *Parser, allocator: std.mem.Allocator) ParseError!Payload {
        try self.expectByte('{');

        var fields = std.ArrayList(Field).empty;
        errdefer fields.deinit(allocator);

        self.skipSpaces();
        if (self.index < self.input.len and self.input[self.index] == '}') {
            self.index += 1;
            return .{ .fields = try fields.toOwnedSlice(allocator) };
        }

        while (true) {
            const key = try self.parseIdentifier();
            try self.expectByte(':');
            const value = try self.parseScalar();
            try fields.append(allocator, .{ .key = key, .value = value });

            self.skipSpaces();
            if (self.index >= self.input.len) return error.UnexpectedEof;
            const ch = self.input[self.index];
            if (ch == ',') {
                self.index += 1;
                continue;
            }
            if (ch == '}') {
                self.index += 1;
                break;
            }
            return error.UnexpectedToken;
        }

        return .{ .fields = try fields.toOwnedSlice(allocator) };
    }
};

pub fn parseInlineMessage(allocator: std.mem.Allocator, text: []const u8) ParseError!Message {
    var parser = Parser{ .input = text };

    var op: ?[]const u8 = null;
    var timestamp: ?u64 = null;
    var dev: ?[]const u8 = null;
    var payload: ?Payload = null;

    try parser.expectByte('{');
    parser.skipSpaces();
    if (parser.index < parser.input.len and parser.input[parser.index] == '}') {
        return error.MissingRequiredField;
    }

    while (true) {
        const key = try parser.parseIdentifier();
        try parser.expectByte(':');

        if (std.mem.eql(u8, key, "op")) {
            op = try parser.parseString();
        } else if (std.mem.eql(u8, key, "t")) {
            const value = try parser.parseInt();
            if (value < 0) return error.NegativeTimestamp;
            timestamp = @intCast(value);
        } else if (std.mem.eql(u8, key, "dev")) {
            dev = try parser.parseString();
        } else if (std.mem.eql(u8, key, "v")) {
            payload = try parser.parsePayload(allocator);
        } else {
            return error.UnknownTopLevelField;
        }

        parser.skipSpaces();
        if (parser.index >= parser.input.len) return error.UnexpectedEof;
        const ch = parser.input[parser.index];
        if (ch == ',') {
            parser.index += 1;
            continue;
        }
        if (ch == '}') {
            parser.index += 1;
            break;
        }
        return error.UnexpectedToken;
    }

    parser.skipSpaces();
    if (parser.index != parser.input.len) {
        return error.UnexpectedToken;
    }

    return .{
        .op = op orelse return error.MissingRequiredField,
        .t = timestamp orelse return error.MissingRequiredField,
        .dev = dev orelse return error.MissingRequiredField,
        .v = payload orelse return error.MissingRequiredField,
    };
}

pub fn scalarEql(a: Scalar, b: Scalar) bool {
    return switch (a) {
        .string => |lhs| switch (b) {
            .string => |rhs| std.mem.eql(u8, lhs, rhs),
            else => false,
        },
        .int => |lhs| switch (b) {
            .int => |rhs| lhs == rhs,
            else => false,
        },
        .boolean => |lhs| switch (b) {
            .boolean => |rhs| lhs == rhs,
            else => false,
        },
    };
}

pub fn messageMatches(expected: Message, actual: Message) bool {
    if (!std.mem.eql(u8, expected.op, actual.op)) return false;
    if (expected.t != actual.t) return false;
    if (!std.mem.eql(u8, expected.dev, actual.dev)) return false;

    for (expected.v.fields) |expected_field| {
        var found = false;
        for (actual.v.fields) |actual_field| {
            if (!std.mem.eql(u8, expected_field.key, actual_field.key)) continue;
            if (!scalarEql(expected_field.value, actual_field.value)) return false;
            found = true;
            break;
        }
        if (!found) return false;
    }

    return true;
}

pub fn formatMessage(msg: Message, writer: anytype) !void {
    try writer.print("{{ op: \"{s}\", t: {}, dev: \"{s}\", v: {{", .{ msg.op, msg.t, msg.dev });

    for (msg.v.fields, 0..) |field, index| {
        if (index > 0) try writer.writeAll(", ");
        try writer.print("{s}: ", .{field.key});
        switch (field.value) {
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .int => |n| try writer.print("{}", .{n}),
            .boolean => |b| try writer.print("{}", .{b}),
        }
    }

    try writer.writeAll(" } }");
}

fn isIdentStart(ch: u8) bool {
    return std.ascii.isAlphabetic(ch) or ch == '_';
}

fn isIdentBody(ch: u8) bool {
    return std.ascii.isAlphanumeric(ch) or ch == '_' or ch == '-';
}

test "parse inline message with scalar payload" {
    const input = "{ op: \"input\", t: 120, dev: \"btn_boot\", v: { action: \"press_down\", count: 2, held: true } }";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const msg = try parseInlineMessage(arena.allocator(), input);
    try std.testing.expect(std.mem.eql(u8, msg.op, "input"));
    try std.testing.expectEqual(@as(u64, 120), msg.t);
    try std.testing.expect(std.mem.eql(u8, msg.dev, "btn_boot"));
    try std.testing.expectEqualStrings("press_down", msg.v.getString("action") orelse return error.MissingAction);
    try std.testing.expectEqual(@as(i64, 2), msg.v.getInt("count") orelse return error.MissingCount);
    try std.testing.expectEqual(true, msg.v.getBool("held") orelse return error.MissingHeld);
}

test "message matches checks key values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const expected = try parseInlineMessage(
        arena.allocator(),
        "{ op: \"set\", t: 55, dev: \"led0\", v: { on: true, r: 255, g: 0, b: 0 } }",
    );
    const actual = try parseInlineMessage(
        arena.allocator(),
        "{ op: \"set\", t: 55, dev: \"led0\", v: { on: true, r: 255, g: 0, b: 0, source: \"sim\" } }",
    );

    try std.testing.expect(messageMatches(expected, actual));
}

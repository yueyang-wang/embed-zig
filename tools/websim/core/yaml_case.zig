const std = @import("std");
const protocol = @import("protocol.zig");

pub const StepKind = enum {
    send,
    expect,
};

pub const Step = struct {
    kind: StepKind,
    message: protocol.Message,
    line_no: usize,
};

pub const CaseFile = struct {
    arena: std.heap.ArenaAllocator,
    source_path: []const u8,
    name: []const u8,
    firmware: []const u8,
    steps: []const Step,

    pub fn deinit(self: *CaseFile) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ParseCaseError = protocol.ParseError || error{
    MissingFirmware,
    MissingSteps,
    InvalidHeader,
    InvalidStep,
    UnsupportedLine,
};

pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !CaseFile {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_alloc = arena.allocator();

    const source_data = try std.fs.cwd().readFileAlloc(arena_alloc, path, 1024 * 1024);
    return parseFromBytesOwned(arena, path, source_data);
}

pub fn parseFromBytes(allocator: std.mem.Allocator, source_path: []const u8, source_data: []const u8) ParseCaseError!CaseFile {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    const arena_alloc = arena.allocator();
    const owned_source = try arena_alloc.dupe(u8, source_data);
    return parseFromBytesOwned(arena, source_path, owned_source);
}

fn parseFromBytesOwned(arena: std.heap.ArenaAllocator, source_path: []const u8, source_data: []const u8) ParseCaseError!CaseFile {
    var case_arena = arena;
    const allocator = case_arena.allocator();

    var steps = std.ArrayList(Step).empty;
    errdefer steps.deinit(allocator);

    var maybe_name: ?[]const u8 = null;
    var maybe_firmware: ?[]const u8 = null;

    var line_no: usize = 0;
    var lines = std.mem.splitScalar(u8, source_data, '\n');
    while (lines.next()) |raw_line| {
        line_no += 1;

        const no_cr = std.mem.trimRight(u8, raw_line, "\r");
        const line = std.mem.trim(u8, no_cr, " \t");
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "#")) continue;
        if (std.mem.eql(u8, line, "steps:")) continue;

        if (std.mem.startsWith(u8, line, "name:")) {
            maybe_name = try parseHeaderValue(line, "name");
            continue;
        }

        if (std.mem.startsWith(u8, line, "firmware:")) {
            maybe_firmware = try parseHeaderValue(line, "firmware");
            continue;
        }

        if (std.mem.startsWith(u8, line, "- send:")) {
            const message_text = std.mem.trim(u8, line[7..], " \t");
            if (message_text.len == 0) return error.InvalidStep;
            const message = try protocol.parseInlineMessage(allocator, message_text);
            try steps.append(allocator, .{ .kind = .send, .message = message, .line_no = line_no });
            continue;
        }

        if (std.mem.startsWith(u8, line, "- expect:")) {
            const message_text = std.mem.trim(u8, line[9..], " \t");
            if (message_text.len == 0) return error.InvalidStep;
            const message = try protocol.parseInlineMessage(allocator, message_text);
            try steps.append(allocator, .{ .kind = .expect, .message = message, .line_no = line_no });
            continue;
        }

        if (line[0] != '-' and std.mem.indexOfScalar(u8, line, ':') != null) {
            // Optional metadata key (e.g. description) - ignored by runner.
            continue;
        }

        return error.UnsupportedLine;
    }

    if (steps.items.len == 0) return error.MissingSteps;

    const firmware = maybe_firmware orelse return error.MissingFirmware;
    const name = maybe_name orelse deriveNameFromPath(source_path);

    return .{
        .arena = case_arena,
        .source_path = try allocator.dupe(u8, source_path),
        .name = name,
        .firmware = firmware,
        .steps = try steps.toOwnedSlice(allocator),
    };
}

fn parseHeaderValue(line: []const u8, comptime key: []const u8) ParseCaseError![]const u8 {
    const prefix = key ++ ":";
    if (!std.mem.startsWith(u8, line, prefix)) return error.InvalidHeader;

    const raw = std.mem.trim(u8, line[prefix.len..], " \t");
    if (raw.len == 0) return error.InvalidHeader;

    if (raw.len >= 2 and raw[0] == '"' and raw[raw.len - 1] == '"') {
        return raw[1 .. raw.len - 1];
    }

    return raw;
}

fn deriveNameFromPath(path: []const u8) []const u8 {
    const base = std.fs.path.basename(path);
    if (base.len == 0) return "unnamed";
    return base;
}

test "parse yaml style case with send and expect" {
    const source =
        \\name: sample case
        \\firmware: 100-button_led_cycle
        \\steps:
        \\  - send: { op: "cmd", t: 0, dev: "sys", v: { cmd: "reset" } }
        \\  - expect: { op: "set", t: 0, dev: "led0", v: { on: false, r: 0, g: 0, b: 0 } }
    ;

    var case_file = try parseFromBytes(std.testing.allocator, "virtual.yaml", source);
    defer case_file.deinit();

    try std.testing.expectEqualStrings("sample case", case_file.name);
    try std.testing.expectEqualStrings("100-button_led_cycle", case_file.firmware);
    try std.testing.expectEqual(@as(usize, 2), case_file.steps.len);
    try std.testing.expectEqual(StepKind.send, case_file.steps[0].kind);
    try std.testing.expectEqual(StepKind.expect, case_file.steps[1].kind);
}

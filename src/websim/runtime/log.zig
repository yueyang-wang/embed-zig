//! Websim stub — Log backend (placeholder, not a real implementation).

pub const Log = struct {
    pub fn debug(_: *Log, _: []const u8) void {}
    pub fn info(_: *Log, _: []const u8) void {}
    pub fn warn(_: *Log, _: []const u8) void {}
    pub fn err(_: *Log, _: []const u8) void {}
};

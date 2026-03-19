//! Websim stub — Fs backend (placeholder, not a real implementation).

const fs_contract = @import("../../runtime/fs.zig");

pub const Fs = struct {
    pub fn open(_: *Fs, _: []const u8, _: fs_contract.OpenMode) ?fs_contract.File {
        return null;
    }
};

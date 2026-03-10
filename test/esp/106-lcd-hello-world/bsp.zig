const inner = @import("board/esp32s3_szp/bsp.zig");

pub const name = inner.name;
pub const allocator = inner.allocator;
pub const log = inner.log;
pub const time = inner.time;
pub const fs = inner.fs;
pub const mountAssets = inner.mountAssets;
pub const unmountAssets = inner.unmountAssets;
pub const printRuntimeStats = inner.printRuntimeStats;
pub const rtc_spec = inner.rtc_spec;
pub const display_spec = inner.display_spec;

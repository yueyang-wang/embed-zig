const inner = @import("board/esp32s3_devkit/bsp.zig");

pub const name = inner.name;
pub const allocator = inner.allocator;
pub const thread = inner.thread;
pub const log = inner.log;
pub const time = inner.time;
pub const sync = inner.sync;
pub const ble_hci_spec = inner.ble_hci_spec;
pub const rtc_spec = inner.rtc_spec;

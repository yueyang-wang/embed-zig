//! Websim stub — AudioSystem HAL (placeholder).

const audio_system = @import("../../hal/audio_system.zig");

pub const AudioSystem = struct {
    pub fn getSampleRate(_: *const AudioSystem) u32 { return 16000; }
    pub fn getMicCount(_: *const AudioSystem) u8 { return 1; }
    pub fn read(_: *AudioSystem) audio_system.Error!audio_system.MicFrame { return error.WouldBlock; }
    pub fn write(_: *AudioSystem, _: []const i16) audio_system.Error!usize { return error.WouldBlock; }
    pub fn setMicGain(_: *AudioSystem, _: u8, _: i8) audio_system.Error!void { return error.Unexpected; }
    pub fn setSpkGain(_: *AudioSystem, _: i8) audio_system.Error!void { return error.Unexpected; }
    pub fn start(_: *AudioSystem) audio_system.Error!void { return error.Unexpected; }
    pub fn stop(_: *AudioSystem) audio_system.Error!void { return error.Unexpected; }
};

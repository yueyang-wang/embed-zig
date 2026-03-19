//! HAL Audio System Contract
//!
//! Unified mic capture + speaker playback + speaker-reference subsystem.
//! The driver owns the entire audio pipeline coordination:
//!
//!   - read() returns all mic channels and a mandatory ref channel
//!   - write() pushes samples to the speaker
//!   - Per-mic and speaker gain control
//!   - Ref-to-mic time alignment is the driver's responsibility
//!
//! Impl must provide all methods listed in the Make() comptime checks.

pub const MicFrame = struct {
    mic: []const []const i16,
    ref: []const i16,
};

pub const Error = error{
    WouldBlock,
    Timeout,
    Overflow,
    InvalidState,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        // info
        _ = @as(*const fn (*const Impl) u32, &Impl.getSampleRate);
        _ = @as(*const fn (*const Impl) u8, &Impl.getMicCount);

        // capture
        _ = @as(*const fn (*Impl) Error!MicFrame, &Impl.read);

        // playback
        _ = @as(*const fn (*Impl, []const i16) Error!usize, &Impl.write);

        // gain
        _ = @as(*const fn (*Impl, u8, i8) Error!void, &Impl.setMicGain);
        _ = @as(*const fn (*Impl, i8) Error!void, &Impl.setSpkGain);

        // lifecycle
        _ = @as(*const fn (*Impl) Error!void, &Impl.start);
        _ = @as(*const fn (*Impl) Error!void, &Impl.stop);
    }

    return struct {
        pub const seal: Seal = .{};
        driver: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .driver = driver };
        }

        pub fn deinit(self: *Self) void {
            self.driver = undefined;
        }

        // -- info --

        pub fn getSampleRate(self: Self) u32 {
            return self.driver.getSampleRate();
        }

        pub fn getMicCount(self: Self) u8 {
            return self.driver.getMicCount();
        }

        // -- capture --

        pub fn read(self: Self) Error!MicFrame {
            return self.driver.read();
        }

        // -- playback --

        pub fn write(self: Self, buffer: []const i16) Error!usize {
            return self.driver.write(buffer);
        }

        // -- gain --

        pub fn setMicGain(self: Self, mic_index: u8, gain_db: i8) Error!void {
            return self.driver.setMicGain(mic_index, gain_db);
        }

        pub fn setSpkGain(self: Self, gain_db: i8) Error!void {
            return self.driver.setSpkGain(gain_db);
        }

        // -- lifecycle --

        pub fn start(self: Self) Error!void {
            return self.driver.start();
        }

        pub fn stop(self: Self) Error!void {
            return self.driver.stop();
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}

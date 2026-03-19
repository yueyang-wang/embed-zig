//! OverrideBuffer — fixed-capacity circular buffer with non-blocking write
//! and blocking read.
//!
//! Write always succeeds immediately, silently overwriting the oldest data
//! when the buffer is full.  Read blocks the caller until at least the
//! requested amount of data (or *some* data) is available.
//!
//! Designed for audio streaming where the producer must never stall and the
//! consumer can afford to wait.

const std = @import("std");
const embed = @import("../../mod.zig");

pub fn OverrideBuffer(comptime T: type, comptime Runtime: type) type {
    comptime _ = embed.runtime.is(Runtime);

    const RawMutex = @typeInfo(@TypeOf(@as(Runtime.Mutex, undefined).impl)).pointer.child;
    const RawCondition = @typeInfo(@TypeOf(@as(Runtime.Condition, undefined).impl)).pointer.child;

    return struct {
        const Self = @This();

        buf: []T,
        capacity: usize,

        write_pos: usize = 0,
        read_pos: usize = 0,
        len: usize = 0,

        raw_mutex: RawMutex,
        raw_cond: RawCondition,
        closed: bool = false,

        pub fn init(buf: []T) Self {
            return .{
                .buf = buf,
                .capacity = buf.len,
                .raw_mutex = RawMutex.init(),
                .raw_cond = RawCondition.init(),
            };
        }

        pub fn deinit(self: *Self) void {
            self.raw_cond.deinit();
            self.raw_mutex.deinit();
        }

        /// Non-blocking write.  Overwrites oldest unread data when full.
        pub fn write(self: *Self, data: []const T) void {
            self.raw_mutex.lock();
            defer self.raw_mutex.unlock();

            for (data) |sample| {
                self.buf[self.write_pos] = sample;
                self.write_pos = (self.write_pos + 1) % self.capacity;

                if (self.len < self.capacity) {
                    self.len += 1;
                } else {
                    self.read_pos = (self.read_pos + 1) % self.capacity;
                }
            }

            if (data.len > 0) self.raw_cond.signal();
        }

        /// Blocking read.  Waits until `out.len` elements are available, then
        /// copies them into `out`.  Returns the number of elements read, which
        /// equals `out.len` under normal operation.
        ///
        /// Returns 0 only when the buffer has been closed and drained.
        pub fn read(self: *Self, out: []T) usize {
            if (out.len == 0) return 0;

            self.raw_mutex.lock();
            defer self.raw_mutex.unlock();

            while (self.len < out.len) {
                if (self.closed) {
                    return self.drainLocked(out);
                }
                self.raw_cond.wait(&self.raw_mutex);
            }

            return self.copyOutLocked(out, out.len);
        }

        pub fn timedRead(self: *Self, out: []T, timeout_ns: u64) usize {
            if (out.len == 0) return 0;

            self.raw_mutex.lock();
            defer self.raw_mutex.unlock();

            if (self.len >= out.len) {
                return self.copyOutLocked(out, out.len);
            }

            if (!self.closed) {
                _ = self.raw_cond.timedWait(&self.raw_mutex, timeout_ns);
            }

            if (self.closed) return self.drainLocked(out);

            const n = @min(self.len, out.len);
            return self.copyOutLocked(out, n);
        }

        pub fn close(self: *Self) void {
            self.raw_mutex.lock();
            defer self.raw_mutex.unlock();
            self.closed = true;
            self.raw_cond.broadcast();
        }

        pub fn reset(self: *Self) void {
            self.raw_mutex.lock();
            defer self.raw_mutex.unlock();
            self.write_pos = 0;
            self.read_pos = 0;
            self.len = 0;
            self.closed = false;
        }

        /// Number of elements available for reading (snapshot, may race).
        pub fn available(self: *Self) usize {
            self.raw_mutex.lock();
            defer self.raw_mutex.unlock();
            return self.len;
        }

        // -- internal helpers (caller holds mutex) ---------------------------

        fn copyOutLocked(self: *Self, out: []T, n: usize) usize {
            for (0..n) |i| {
                out[i] = self.buf[self.read_pos];
                self.read_pos = (self.read_pos + 1) % self.capacity;
            }
            self.len -= n;
            return n;
        }

        fn drainLocked(self: *Self, out: []T) usize {
            if (self.len == 0) return 0;
            const n = @min(self.len, out.len);
            return self.copyOutLocked(out, n);
        }
    };
}

const std = @import("std");

const FactorySeal = struct {};

pub fn RecvResult(comptime T: type) type {
    return struct { value: T, ok: bool };
}

pub fn SendResult() type {
    return struct { ok: bool };
}

/// Bind a backend factory to produce sealed Channel types.
///
/// Usage:
///   const f = channel_factory.Make(std_channel_factory.ChannelFactory);
///   const EventCh = f.Channel(MyEvent);
///   var ch = try EventCh.init(allocator, 16);
pub fn Make(comptime impl: fn (type) type) type {
    return struct {
        pub const seal: FactorySeal = .{};

        pub fn Channel(comptime T: type) type {
            const Ch = impl(T);

            comptime {
                _ = @as(*const fn () void, &Ch.isSelectable);
                _ = @as(*const fn (*Ch, T) anyerror!SendResult(), &Ch.send);
                _ = @as(*const fn (*Ch) anyerror!RecvResult(T), &Ch.recv);
                _ = @as(*const fn (*Ch) void, &Ch.close);
                _ = @as(*const fn (*Ch) void, &Ch.deinit);
                _ = @as(*const fn (std.mem.Allocator, usize) anyerror!Ch, &Ch.init);
            }

            return struct {
                pub const event_t = T;
                pub const channel_t = Ch;


                ch: channel_t,

                pub fn init(allocator: std.mem.Allocator, capacity: usize) !@This() {
                    return .{
                        .ch = try Ch.init(allocator, capacity),
                    };
                }

                pub fn deinit(self: *@This()) void {
                    self.ch.deinit();
                }

                pub fn close(self: *@This()) void {
                    self.ch.close();
                }

                pub fn send(self: *@This(), value: event_t) !SendResult() {
                    return try self.ch.send(value);
                }

                pub fn recv(self: *@This()) !RecvResult(T) {
                    return try self.ch.recv();
                }
            };
        }
    };
}

/// Check whether T is a sealed Channel Factory (produced via Make).
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == FactorySeal;
}

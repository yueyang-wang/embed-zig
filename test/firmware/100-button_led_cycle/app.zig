//! 100-button_led_cycle — Button-driven LED color cycling via AppRuntime.
//!
//! Demonstrates the full flux pipeline:
//!   event.Bus → gesture middleware → Animator → output
//!
//! Behavior:
//!   - 1 click:  → red (fade)
//!   - 2 clicks: → green (fade)
//!   - 3 clicks: → blue (fade)
//!   - 4 clicks: → white (fade)
//!   - Long press: → toggle off / white (fade)

const embed = @import("embed");
const runtime = embed.runtime;
const event = embed.pkg.event;
const app_mod = embed.pkg.app;

pub const App = @import("state.zig");

pub fn run(comptime hw: type, env: anytype) void {
    _ = env;

    const board_spec = @import("board_spec.zig");
    const Board = board_spec.Board(hw);

    const IO = runtime.io.from(hw.io);
    const Thread = Board.thread.Type;
    const Gpio = Board.gpio;

    const ButtonType = event.button.GpioButton(Gpio, Board.time, IO, App.Event, "button");
    const GestureType = event.button.ButtonGesture(App.Event, "button", Board.time);
    const EventLog = event.Logger(App.Event, Board.log, "button");
    const AppRt = app_mod.AppRuntime(App, IO);

    const log: Board.log = .{};
    const time: Board.time = .{};
    const allocator = Board.allocator.system;

    var board: Board = undefined;
    board.init() catch {
        log.err("board init failed");
        return;
    };
    defer board.deinit();

    var io = IO.init(allocator) catch {
        log.err("io init failed");
        return;
    };
    defer io.deinit();

    var btn = ButtonType.init(&board.gpio_dev, &io, time, .{
        .id = "btn.boot",
        .pin = hw.button_pin,
        .active_level = .low,
    }) catch {
        log.err("button init failed");
        return;
    };
    defer btn.deinit();
    btn.bind();

    var gesture = GestureType.init(time, .{
        .multi_click_window_ms = 300,
        .long_press_ms = 500,
    });

    var rt = AppRt.init(allocator, &io, .{
        .poll_timeout_ms = 50,
    });
    defer rt.deinit();

    rt.register(&btn.periph) catch {
        log.err("register button failed");
        return;
    };
    rt.use(EventLog.middleware("raw"));
    rt.use(gesture.middleware());
    rt.use(EventLog.middleware("gesture"));
    rt.use(.{ .ctx = null, .tickFn = App.tickMiddleware });

    var btn_thread = Thread.spawn(
        Board.thread.user,
        ButtonType.runFromCtx,
        @ptrCast(&btn),
    ) catch {
        log.err("button worker start failed");
        return;
    };
    defer {
        btn.requestStop();
        btn_thread.join();
    }

    log.info("100-button_led_cycle started");

    while (Board.isRunning()) {
        rt.tick();

        if (rt.isDirty()) {
            const state = rt.getState();
            const prev = rt.getPrev();

            if (!state.led.current.eql(prev.led.current)) {
                board.led_strip_dev.setPixels(&state.led.current.pixels);
            }

            rt.commitFrame();
        }
    }

    log.info("100-button_led_cycle stopped");
}

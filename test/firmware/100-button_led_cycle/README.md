# 100-button_led_cycle Firmware

## 对外接口（唯一）

本固件包只对外暴露一个入口：

```zig
pub fn run(runtime: anytype, board: anytype) !void
```

不再对外暴露 `handleEvent/processEvent/init/deinit` 等接口。

## 生命周期约束

`run` 内部负责完整生命周期：

1. 开始时初始化：`runtime.init()`、`board.init()`
2. 事件循环：读取 board 事件并驱动 LED 状态机
3. 退出时释放：`board.deinit()`、`runtime.deinit()`

即调用方不需要关心固件内部对象管理，只需要调用一次 `run(runtime, board)`。

## 目录职责

```text
100-button_led_cycle/
├── README.md
├── root.zig         # 对外只导出 run(runtime, board)
├── app.zig          # 业务状态机（off/white/red/green）
├── env.zig          # 事件解析与 board LED 适配
├── runtime_spec.zig # 时间阈值与设备 ID 约束
├── test/*.yaml
└── ui/style/*
```

## 行为规则

- 设备：`btn_boot`（输入），`led0`（输出）
- 长按（>=1000ms）释放：`off <-> white`
- 单击：切到 `red`
- 双击（300ms 窗口）：切到 `green`
- `reset`：清空内部状态并输出 `off`

## 与 sim/main.zig 的关系

- `sim/main.zig` 作为程序入口，负责构造 runtime + board。
- 然后调用 firmware 包提供的 `run(runtime, board)`。
- 固件层仅负责业务逻辑与设备交互，不承担进程入口职责。

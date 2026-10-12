# glava-audio

把 Termux 里的系统声音（PulseAudio）桥接到 [glava](https://github.com/jarcode-foss/glava)
的 `fifo` 音频源，这样音乐、视频、Wine 游戏的声音都能驱动可视化。

## 音频链路

```
应用 / 游戏
    │
    ▼
glava_mix (module-null-sink)         虚拟混音总输出
    │  monitor
    ▼
module-loopback
    │
    ▼
glava_fifo (module-pipe-sink)        写成裸 PCM
    │
    ▼
$PREFIX/tmp/glava.fifo               s16le / 44100Hz / 2ch
    │
    ▼
glava -a fifo                        可视化
```

## 安装

```bash
pkg install glava-audio
# 会自动带上 pulseaudio、sox；glava 作为 recommends
```

## 用法

```bash
glava-audio start        # 启动 PulseAudio 桥（后台）
glava-audio glava        # 另开终端：启动可视化
glava-audio test-bass    # 再开一个终端：播放测试音
glava-audio stop         # 停止
```

### 全部子命令

| 命令 | 说明 |
|---|---|
| `start` | 启动 PulseAudio 桥 |
| `stop` | 停止 |
| `restart` | 重启 |
| `status` | 查看状态与 sink 列表 |
| `sinks` | 列出所有 sink 及其格式 |
| `test` | 5 秒扫频测试音（220→1200Hz） |
| `test-bass` | 8 秒低音脉冲（可视化明显） |
| `test-file <文件>` | 播放任意音频文件作为信号源 |
| `glava` | 启动 glava，自动指向 FIFO |

## 配置

- 采样率：`GLAVA_RATE=48000 glava-audio start`
  （默认 44100；用 `glava-audio sinks` 查看设备实际采样率）
- 配置模板：`$PREFIX/etc/glava-audio/pa.cfg`
- 运行时生成：`$PREFIX/tmp/glava-audio/pa.cfg`
- 日志：`$PREFIX/tmp/glava-audio/pulse.log`

## 注意事项

1. **FIFO 路径**：Termux 把 `/tmp` 重定向到 `$PREFIX/tmp`，
   所以 FIFO 是 `$PREFIX/tmp/glava.fifo` 而不是 `/tmp/glava.fifo`。
2. **格式**：glava 的 `fifo` 后端按 int16 小端、立体声读取
   （源码 `glava/fifo.c`）。
3. **静音时**：pipe-sink 会持续写零数据，但 glava 有 `poll()` 超时处理，
   不会卡死。
4. **Wine 游戏**：`set-default-sink glava_fifo` 后，所有走 PulseAudio
   的程序（含 Wine 游戏）都会自动进入 FIFO。
5. **需要 X**：glava 本体需要 X 显示，通常搭配 `termux-x11`
   使用（`export DISPLAY=:0`）。

## 许可证

GPL-3.0（与 glava 一致）

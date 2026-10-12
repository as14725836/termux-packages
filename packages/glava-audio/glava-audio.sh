#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
#  glava-audio —— 把系统声音（PulseAudio）桥接到 glava 的 FIFO 音频源
# ----------------------------------------------------------------------------
#  音频链路：
#     应用 / 游戏  →  glava_mix (null-sink)  →  module-loopback
#                  →  glava_fifo (pipe-sink)  →  $PREFIX/tmp/glava.fifo
#                  →  glava -a fifo
#
#  用法：
#     glava-audio start        启动桥（后台）
#     glava-audio stop         停止
#     glava-audio restart      重启
#     glava-audio status       查看状态
#     glava-audio sinks        列出 PulseAudio sink
#     glava-audio test         播放 5 秒扫频测试音
#     glava-audio test-bass    播放 8 秒低音脉冲（可视化效果好）
#     glava-audio test-file F  播放音频文件 F
#     glava-audio glava        启动 glava（自动指向 FIFO）
#
#  环境变量：
#     GLAVA_RATE=48000         改采样率（默认 44100）
# ============================================================================
set -u

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

FIFO="$PREFIX/tmp/glava.fifo"
RUNDIR="$PREFIX/tmp/glava-audio"
SOCK="$RUNDIR/native"
LOG="$RUNDIR/pulse.log"
CFG="$RUNDIR/pa.cfg"
RCFG="$PREFIX/etc/glava-audio/pa.cfg"
PAPID="$RUNDIR/pa.pid"

RATE="${GLAVA_RATE:-44100}"

export PULSE_SERVER="unix:$SOCK"

mkdir -p "$RUNDIR"

die() { echo "错误: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "缺少 $1，请先 pkg install $2"; }

write_cfg() {
	# 基于随包安装的模板生成实际配置（替换占位符）
	if [ -f "$RCFG" ]; then
		sed -e "s|@TERMUX_PREFIX@|$PREFIX|g" \
		    -e "s|@RATE@|$RATE|g" \
		    "$RCFG" > "$CFG"
	else
		cat > "$CFG" <<EOF
load-module module-null-sink sink_name=glava_mix sink_properties=device.description=GlavaMix
load-module module-pipe-sink sink_name=glava_fifo file=$FIFO format=s16le rate=$RATE channels=2
set-default-sink glava_fifo
load-module module-loopback source=glava_mix.monitor sink=glava_fifo
EOF
	fi
}

is_running() {
	[ -f "$PAPID" ] && kill -0 "$(cat "$PAPID" 2>/dev/null)" 2>/dev/null
}

cmd_start() {
	if is_running; then
		echo "PulseAudio 桥已在运行 (pid $(cat "$PAPID"))"
		echo "FIFO: $FIFO"
		return 0
	fi
	need pulseaudio pulseaudio
	write_cfg
	rm -f "$FIFO" "$LOG"

	setsid pulseaudio -n --file="$CFG" --daemonize=no \
		--exit-idle-time=-1 --disallow-exit \
		--load="module-native-protocol-unix socket=$SOCK auth-anonymous=1" \
		--log-target="file:$LOG" >/dev/null 2>&1 </dev/null &
	echo $! > "$PAPID"

	for _ in $(seq 1 30); do
		sleep 0.3
		[ -S "$SOCK" ] && [ -p "$FIFO" ] && break
	done

	if [ -p "$FIFO" ]; then
		echo "✅ PulseAudio 桥已启动"
		echo "   FIFO   : $FIFO"
		echo "   socket : $SOCK"
		echo "   格式   : s16le / ${RATE}Hz / 2ch"
		echo ""
		echo "下一步："
		echo "   glava-audio glava       # 启动可视化"
		echo "   glava-audio test-bass   # 播放测试音"
	else
		echo "❌ 启动失败，日志：$LOG" >&2
		tail -20 "$LOG" 2>/dev/null >&2
		return 1
	fi
}

cmd_stop() {
	if is_running; then
		kill "$(cat "$PAPID")" 2>/dev/null
		sleep 1
		echo "已停止 PulseAudio 桥"
	else
		echo "没有在运行"
	fi
	rm -f "$PAPID" "$SOCK"
}

cmd_status() {
	if is_running; then
		echo "PulseAudio : 运行中 (pid $(cat "$PAPID"))"
	else
		echo "PulseAudio : 未运行"
	fi
	[ -p "$FIFO" ] && echo "FIFO       : 存在 ($FIFO)" || echo "FIFO       : 不存在"
	if [ -S "$SOCK" ]; then
		echo ""
		pactl list sinks short 2>/dev/null
	fi
}

cmd_sinks() {
	[ -S "$SOCK" ] || die "PulseAudio 未运行，先 glava-audio start"
	pactl list sinks 2>/dev/null | grep -E "Name:|State:|Sample Specification:"
}

# 把 stdin 的裸 PCM 送去 glava_mix
pipe_to_mix() {
	need pacat pulseaudio
	pacat --rate="$RATE" --channels=2 --format=s16le --device=glava_mix --raw
}

need_sox() { need sox sox; }

cmd_test() {
	need_sox
	echo "播放 5 秒扫频（220Hz → 1200Hz）…"
	sox -n -t raw -r "$RATE" -c 2 -b 16 -e signed - 2>/dev/null \
		synth 5 sine 220 vol 0.6 synth 5 sine 1200 vol 0.6 | pipe_to_mix
	echo "完成"
}

cmd_test_bass() {
	need_sox
	echo "播放 8 秒低音脉冲…"
	sox -n -t raw -r "$RATE" -c 2 -b 16 -e signed - 2>/dev/null \
		synth 8 sine 60 vol 0.8 tremolo 4 40 | pipe_to_mix
	echo "完成"
}

cmd_test_file() {
	local f="${2:-}"
	[ -n "$f" ] || die "用法: glava-audio test-file <音频文件>"
	[ -f "$f" ] || die "文件不存在: $f"
	need_sox
	echo "播放 $f …"
	sox "$f" -t raw -r "$RATE" -c 2 -b 16 -e signed - 2>/dev/null | pipe_to_mix
	echo "完成"
}

cmd_glava() {
	need glava glava
	[ -p "$FIFO" ] || die "FIFO 不存在，先运行：glava-audio start"
	export DISPLAY="${DISPLAY:-:0}"
	echo "启动 glava（DISPLAY=$DISPLAY, FIFO=$FIFO）…"
	exec glava -a fifo --request "setsource \"$FIFO\""
}

case "${1:-help}" in
	start)     cmd_start ;;
	stop)      cmd_stop ;;
	restart)   cmd_stop; sleep 1; cmd_start ;;
	status)    cmd_status ;;
	sinks)     cmd_sinks ;;
	test)      cmd_test ;;
	test-bass) cmd_test_bass ;;
	test-file) cmd_test_file "$@" ;;
	glava)     cmd_glava ;;
	help|-h|--help|*)
		sed -n '/^# ====/,/^# ====/p' "$0" | sed 's/^# \{0,1\}//'
		;;
esac

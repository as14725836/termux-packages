TERMUX_PKG_HOMEPAGE=https://github.com/jarcode-foss/glava
TERMUX_PKG_DESCRIPTION="PulseAudio-to-FIFO audio bridge for glava (Termux)"
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_MAINTAINER="@as14725836"
TERMUX_PKG_VERSION=1.0.0
TERMUX_PKG_REVISION=1
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_PLATFORM_INDEPENDENT=true
TERMUX_PKG_SKIP_SRC_EXTRACT=true
TERMUX_PKG_DEPENDS="pulseaudio, sox"
TERMUX_PKG_RECOMMENDS="glava"
TERMUX_PKG_SUGGESTS="termux-x11"
TERMUX_PKG_CONFFILES="etc/glava-audio/pa.cfg"

# This package only ships shell scripts and a config file, so there is nothing
# to configure or compile. Without these overrides the build would pick up a
# meson.build left behind by an earlier glava build in the same tree.
termux_step_configure() {
	:
}

termux_step_make() {
	:
}

termux_step_make_install() {
	install -Dm700 "$TERMUX_PKG_BUILDER_DIR/glava-audio.sh" \
		"$TERMUX_PREFIX/bin/glava-audio"
	install -Dm600 "$TERMUX_PKG_BUILDER_DIR/pa.cfg" \
		"$TERMUX_PREFIX/etc/glava-audio/pa.cfg"

	# README 一并装好，方便 `glava-audio help` 之外的地方查看
	install -Dm600 "$TERMUX_PKG_BUILDER_DIR/README.md" \
		"$TERMUX_PREFIX/share/doc/glava-audio/README.md"
}

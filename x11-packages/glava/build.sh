TERMUX_PKG_HOMEPAGE=https://github.com/jarcode-foss/glava
TERMUX_PKG_DESCRIPTION="OpenGL audio spectrum visualizer"
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_MAINTAINER="@as14725836"
TERMUX_PKG_VERSION="1.6.3"
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL="https://github.com/jarcode-foss/glava/archive/6fc0e32da2c54954a3784c2ced1024e576ba8d8d.tar.gz"
TERMUX_PKG_SHA256=7114f038ae866f8b6657de555e885ccf909dae7baf1d2f8b6d46430fdc7ae2dc
TERMUX_PKG_DEPENDS="libblocksruntime, libc++, libglvnd, libx11, libxext, libxrender, libxcomposite, opengl"
TERMUX_PKG_BUILD_DEPENDS="libglvnd-dev, xorgproto"

# PulseAudio is not available on Termux/Android; the FIFO audio backend is
# used instead (see patch 01). Configuration tool (GTK+Lua) and the OBS
# plugin are disabled as their dependencies are not available.
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-Ddisable_config=true
-Ddisable_obs=true
-Ddisable_pulse=true
-Denable_glfw=false
-Dshader_install_dir=$TERMUX_PREFIX/etc/xdg
-Dresource_install_dir=$TERMUX_PREFIX/share/glava
"

termux_step_pre_configure() {
	termux_setup_meson
}

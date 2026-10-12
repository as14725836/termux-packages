TERMUX_PKG_HOMEPAGE=https://github.com/as14725836/gladio-termux
TERMUX_PKG_DESCRIPTION="Gladio renderer server: OpenGL to GLES wrapper for Winlator/Wine on Termux:X11"
TERMUX_PKG_LICENSE="LGPL-2.1"
TERMUX_PKG_MAINTAINER="@as14725836"
TERMUX_PKG_VERSION="1.0.0"
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL="https://github.com/as14725836/gladio-termux/archive/d59824e1600c44edb0549ad21d5f84f69fe26e68.tar.gz"
TERMUX_PKG_SHA256=36060c6f3e7dbebf54da8ae55ef508d3dd4714d1482828a5ee05ef33d2fca41d
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_PLATFORM_INDEPENDENT=false
# The renderer drives GLES through EGL and presents with X11 MIT-SHM.
# libglvnd provides libEGL.so/libGLESv2.so; libglvnd-dev carries the headers.
TERMUX_PKG_DEPENDS="libx11, libxext, libglvnd"
TERMUX_PKG_BUILD_DEPENDS="xorgproto, libglvnd-dev"

# There is no CMakeLists.txt at the top of the source tree (the renderer lives
# in server/gladiorenderer), so point the stock cmake helper at that
# subdirectory and reuse it: it handles the toolchain flags and install paths.
#
# -DCMAKE_SYSTEM_NAME=Linux is appended after the helper's own
# -DCMAKE_SYSTEM_NAME=Android so it wins, keeping CMake out of its Android
# mode. That mode derives --target=aarch64-none-linux-android from
# CMAKE_ANDROID_ARCH_LLVM_TRIPLE and only appends the API level when
# CMAKE_ANDROID_NDK_TOOLCHAIN_UNIFIED is set, which never happens with a
# standalone toolchain; the resulting target has no API-levelled sysroot
# subdirectory and the compiler probe fails with "cannot open
# crtbegin_dynamic.o". With CMAKE_SYSTEM_NAME=Linux the compilers are used
# as-is and $CFLAGS carries --target=$CCTERMUX_HOST_PLATFORM unchanged, which
# is what the glibc build of this server wants anyway.
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DCMAKE_SYSTEM_NAME=Linux
-DGLADIO_BUILD_CLI=ON
"

termux_step_configure() {
	termux_setup_cmake
	termux_setup_ninja

	local TERMUX_PKG_SRCDIR_SAVE="$TERMUX_PKG_SRCDIR"
	TERMUX_PKG_SRCDIR="$TERMUX_PKG_SRCDIR_SAVE/server/gladiorenderer"
	termux_step_configure_cmake
	TERMUX_PKG_SRCDIR="$TERMUX_PKG_SRCDIR_SAVE"
}

termux_step_make_install() {
	install -Dm755 "$TERMUX_PKG_BUILDDIR/gladio-cli" \
		"$TERMUX_PREFIX/bin/gladio-cli"
}

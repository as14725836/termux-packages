TERMUX_PKG_HOMEPAGE=https://github.com/as14725836/gladio-termux
TERMUX_PKG_DESCRIPTION="Gladio renderer server: OpenGL to GLES wrapper for Winlator/Wine on Termux:X11"
TERMUX_PKG_LICENSE="LGPL-2.1"
TERMUX_PKG_MAINTAINER="@as14725836"
TERMUX_PKG_VERSION="1.0.0"
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL="https://github.com/as14725836/gladio-termux/archive/3225ae0e9a5150fef9c6e87444bc244d2212c35a.tar.gz"
TERMUX_PKG_SHA256=c49b137f9ec5e3d00904e503c0b40f90bcfe64cbbce1a2a40e73d959cd6ffffd
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_PLATFORM_INDEPENDENT=false
# The renderer drives GLES through EGL and presents with X11 MIT-SHM.
# libglvnd is the dispatcher providing libEGL.so/libGLESv2.so and libglvnd-dev
# carries the headers. The MIT-SHM path uses SysV shmget/shmat, which bionic
# lacks; libandroid-shmem supplies those along with <sys/shm.h>.
#
# A driver to sit behind the dispatcher is recommended rather than required:
# mesa is the usual one, but the point of this package is to run against a
# custom EGL implementation, and a hard dependency would pull mesa in
# alongside it.
TERMUX_PKG_DEPENDS="libandroid-shmem, libx11, libxext, libglvnd"
TERMUX_PKG_RECOMMENDS="mesa"
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
# is used as-is and $CFLAGS carries --target=$CCTERMUX_HOST_PLATFORM unchanged,
# so the CLI is compiled against the bionic API level Termux selects and links
# against the Termux libraries rather than the NDK sysroot.
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

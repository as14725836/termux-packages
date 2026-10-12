TERMUX_PKG_HOMEPAGE=https://github.com/as14725836/vortek-termux
TERMUX_PKG_DESCRIPTION="Vortek renderer server: Vulkan compatibility layer for Winlator/Wine on Termux:X11"
TERMUX_PKG_LICENSE="LGPL-2.1"
TERMUX_PKG_MAINTAINER="@as14725836"
TERMUX_PKG_VERSION="1.0.0"
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL="https://github.com/as14725836/vortek-termux/archive/f80c808166a4f3a8bef08aa33bf0eea8f00fc57d.tar.gz"
TERMUX_PKG_SHA256=669389dbaef98d2341dc3f990d2840fce3d1c957b0256efe526f6365cd335b49
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_PLATFORM_INDEPENDENT=false
# The renderer drives an Adreno driver through libadrenotools, which only
# supports arm64-v8a, and the CLI targets aarch64-linux-android explicitly.
TERMUX_PKG_EXCLUDED_ARCHES="arm, i686, x86_64"

# Runtime: the CLI links X11/xcb/xshmfence and creates its shared-memory rings
# through android-shmem. The glibc-side client ICD (libvulkan_vortek.so) is a
# separate artefact and is not part of this package.
TERMUX_PKG_DEPENDS="libandroid-shmem, libx11, libxcb, libxext, libxshmfence"
TERMUX_PKG_BUILD_DEPENDS="xorgproto"

# libadrenotools is vendored under server/libadrenotools and has to be built
# before the renderer links against it; see termux_step_pre_configure.
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DVORTEK_BUILD_CLI=ON
-DVORTEK_BUILD_JNI=OFF
-DVORTEK_CLI_BUNDLE_WINLATOR_SOURCES=ON
-DVORTEK_CLI_X11=ON
-DVORTEK_CLI_ANDROID_API=$TERMUX_PKG_API_LEVEL
-DADRENOTOOLS_INCLUDE_DIR=$TERMUX_PKG_SRCDIR/server/libadrenotools/include
-DWINLATOR_SOURCE_DIR=$TERMUX_PKG_SRCDIR/server/winlator
-DADRENOTOOLS_LIBRARY=adrenotools
-DCMAKE_INSTALL_PREFIX=$TERMUX_PREFIX
"

# There is no CMakeLists.txt at the top of the source tree (the renderer lives
# in server/vortekrenderer), so the default configure step would be skipped.
# Configure that subdirectory explicitly instead.
termux_step_configure() {
	termux_setup_cmake
	termux_setup_ninja

	cmake -G Ninja \
		-S "$TERMUX_PKG_SRCDIR/server/vortekrenderer" \
		-B "$TERMUX_PKG_BUILDDIR" \
		-DCMAKE_SYSTEM_NAME=Android \
		-DCMAKE_SYSTEM_VERSION="$TERMUX_PKG_API_LEVEL" \
		-DCMAKE_ANDROID_STANDALONE_TOOLCHAIN="$TERMUX_STANDALONE_TOOLCHAIN" \
		-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
		-DCMAKE_C_COMPILER="$CC" \
		-DCMAKE_CXX_COMPILER="$CXX" \
		-DCMAKE_AR="$(command -v "$AR")" \
		-DCMAKE_RANLIB="$(command -v "$RANLIB")" \
		-DCMAKE_STRIP="$(command -v "$STRIP")" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_FIND_ROOT_PATH="$TERMUX_PREFIX" \
		-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
		-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
		-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
		-DCMAKE_INSTALL_LIBDIR="$TERMUX__PREFIX__LIB_DIR" \
		-DCMAKE_INSTALL_INCLUDEDIR="$TERMUX__PREFIX__INCLUDE_DIR" \
		-DCMAKE_SKIP_INSTALL_RPATH=ON \
		-DCMAKE_USE_SYSTEM_LIBRARIES=True \
		$TERMUX_PKG_EXTRA_CONFIGURE_ARGS
}

termux_step_pre_configure() {
	# pre_configure runs before termux_step_configure, so the cmake/ninja
	# helpers have not been fetched yet. Pull them in here because we need
	# cmake for libadrenotools already.
	termux_setup_cmake
	termux_setup_ninja

	# Upstream ships no aggregating CMakeLists for libadrenotools, so build it
	# here. Its src/ and src/hook/ targets produce libadrenotools.so plus the
	# libhook_impl.so / libmain_hook.so hook payloads the CLI loads at runtime.
	local adreno_build="$TERMUX_PKG_BUILDDIR/adrenotools"
	cmake -S "$TERMUX_PKG_SRCDIR/server/libadrenotools" -B "$adreno_build" \
		-G Ninja \
		-DCMAKE_SYSTEM_NAME=Android \
		-DCMAKE_SYSTEM_VERSION="$TERMUX_PKG_API_LEVEL" \
		-DCMAKE_ANDROID_STANDALONE_TOOLCHAIN="$TERMUX_STANDALONE_TOOLCHAIN" \
		-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
		-DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
		-DCMAKE_AR="$(command -v "$AR")" \
		-DCMAKE_RANLIB="$(command -v "$RANLIB")" \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SHARED_LIBS=ON \
		-DCMAKE_LIBRARY_OUTPUT_DIRECTORY="$TERMUX_PKG_BUILDDIR/adreno-lib"
	cmake --build "$adreno_build" -j"$(nproc)"

	# The renderer links the adrenotools symbol even though the library is
	# dlopen()ed at runtime, so make the fresh build directory visible to the
	# linker.
	LDFLAGS+=" -L$TERMUX_PKG_BUILDDIR/adreno-lib"
}

termux_step_make_install() {
	install -Dm755 "$TERMUX_PKG_BUILDDIR/vortekrenderer-cli" \
		"$TERMUX_PREFIX/bin/vortekrenderer-cli"

	# setDefaultAdrenotoolsHookDir() probes $PREFIX/lib first, so placing the
	# hook payloads there lets the CLI find them without any extra flags.
	install -Dm755 "$TERMUX_PKG_BUILDDIR/adreno-lib/libhook_impl.so" \
		"$TERMUX_PREFIX/lib/libhook_impl.so"
	install -Dm755 "$TERMUX_PKG_BUILDDIR/adreno-lib/libmain_hook.so" \
		"$TERMUX_PREFIX/lib/libmain_hook.so"

	install -Dm644 "$TERMUX_PKG_BUILDDIR/adreno-lib/libadrenotools.so" \
		"$TERMUX_PREFIX/lib/libadrenotools.so"
}

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
# The CLI needs AHardwareBuffer (API 26) and the renderer targets
# aarch64-linux-android26. Termux defaults to API 24, which is too low, so pin
# it here; it also becomes the -DVORTEK_CLI_ANDROID_API value below.
TERMUX_PKG_API_LEVEL=26
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
-DCMAKE_SYSTEM_NAME=Linux
-DVORTEK_BUILD_CLI=ON
-DVORTEK_BUILD_JNI=OFF
-DVORTEK_CLI_BUNDLE_WINLATOR_SOURCES=ON
-DVORTEK_CLI_X11=ON
-DVORTEK_CLI_ANDROID_API=$TERMUX_PKG_API_LEVEL
-DADRENOTOOLS_INCLUDE_DIR=$TERMUX_PKG_SRCDIR/server/libadrenotools/include
-DWINLATOR_SOURCE_DIR=$TERMUX_PKG_SRCDIR/server/winlator
-DADRENOTOOLS_LIBRARY=adrenotools
"

# There is no CMakeLists.txt at the top of the source tree (the renderer lives
# in server/vortekrenderer), so the default configure step would be skipped.
# Point the stock cmake helper at that subdirectory and reuse it: it handles
# the toolchain flags and the install paths, and the extra
# -DCMAKE_SYSTEM_NAME=Linux above (which is appended after the helper's own
# -DCMAKE_SYSTEM_NAME=Android, so it wins) keeps CMake out of its Android
# mode. That mode derives --target=aarch64-none-linux-android from
# CMAKE_ANDROID_ARCH_LLVM_TRIPLE and only appends the API level when
# CMAKE_ANDROID_NDK_TOOLCHAIN_UNIFIED is set, which never happens with a
# standalone toolchain. The resulting target has no API-leveled sysroot
# subdirectory, so the compiler probe fails with "cannot open
# crtbegin_dynamic.o" and "unable to find library -lc++". With
# CMAKE_SYSTEM_NAME=Linux the compilers are used as-is, and $CFLAGS carries
# --target=$CCTERMUX_HOST_PLATFORM unchanged.
termux_step_configure() {
	termux_setup_cmake
	termux_setup_ninja

	local TERMUX_PKG_SRCDIR_SAVE="$TERMUX_PKG_SRCDIR"
	TERMUX_PKG_SRCDIR="$TERMUX_PKG_SRCDIR_SAVE/server/vortekrenderer"
	termux_step_configure_cmake
	TERMUX_PKG_SRCDIR="$TERMUX_PKG_SRCDIR_SAVE"
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
	#
	# CMAKE_SYSTEM_NAME=Linux keeps this out of CMake's Android mode for the
	# same reason as the renderer build above. $CC/$CXX already target
	# aarch64-linux-android$TERMUX_PKG_API_LEVEL through the standalone
	# toolchain wrappers, so no Android-specific handling is required; passing
	# --target explicitly is defensive, in case a future helper stops doing it.
	local adreno_build="$TERMUX_PKG_BUILDDIR/adrenotools"
	cmake -S "$TERMUX_PKG_SRCDIR/server/libadrenotools" -B "$adreno_build" \
		-G Ninja \
		-DCMAKE_SYSTEM_NAME=Linux \
		-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
		-DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
		-DCMAKE_C_FLAGS="--target=$CCTERMUX_HOST_PLATFORM $CFLAGS $CPPFLAGS" \
		-DCMAKE_CXX_FLAGS="--target=$CCTERMUX_HOST_PLATFORM $CXXFLAGS $CPPFLAGS" \
		-DCMAKE_EXE_LINKER_FLAGS="--target=$CCTERMUX_HOST_PLATFORM $LDFLAGS" \
		-DCMAKE_SHARED_LINKER_FLAGS="--target=$CCTERMUX_HOST_PLATFORM $LDFLAGS" \
		-DCMAKE_AR="$(command -v "$AR")" \
		-DCMAKE_RANLIB="$(command -v "$RANLIB")" \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SHARED_LIBS=ON \
		-DCMAKE_LIBRARY_OUTPUT_DIRECTORY="$TERMUX_PKG_BUILDDIR/adreno-lib"
	cmake --build "$adreno_build" -j"$(nproc)"

	# libadrenotools installs its hook payloads next to the shared objects, so
	# keep the same layout in the build tree.
	mkdir -p "$TERMUX_PKG_BUILDDIR/adreno-lib"

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

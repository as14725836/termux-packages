# gladiorenderer

Server half of [gladio](https://github.com/brunodev85/gladio), the OpenGL→GLES
wrapper Winlator uses to run OpenGL applications. This package installs
`gladio-cli`, a standalone build of the renderer that presents through X11
instead of the Winlator APK's Java surface.

## How it fits together

```
  Windows app
      │  OpenGL calls
      ▼
  libGL.so            (gladio client, inside the Wine rootfs)
      │  binary requests over a Unix socket + shared-memory rings
      ▼
  gladio-cli          (this package)
      │  GLES calls through EGL
      ▼
  Termux:X11  ──►  screen
```

The client is the glibc `libGL.so` published with gladio; this package is only
the server. It expects the client's `X11_SERVER_PATH` to point at the socket
`gladio-cli` listens on.

## Install

```
pkg install gladiorenderer
```

## Usage

Start the server before the client — the client connects once from inside
`glXGetProcAddress()` and does not retry in-process:

```
gladio-cli -s "$PREFIX/tmp/.gladio/G0"
```

Options:

| Flag | Meaning |
| --- | --- |
| `-s`, `--socket PATH` | Unix socket to listen on (default `$PREFIX/tmp/.gladio/G0`) |
| `-d`, `--display NAME` | X11 display to present on (default `$DISPLAY`) |
| `--once` | Serve a single client and exit |
| `-h`, `--help` | Show usage |

Presentation needs a running X server. When the X server advertises the
MIT-SHM extension the frame path uses `XShmPutImage` for zero-copy transfer and
falls back to `XPutImage` otherwise.

## Notes

* The renderer generates **GLSL ES 3.20** shaders, so the GL driver must
  support ES 3.2. This is what Adreno and the Termux Mesa build provide; a
  software rasteriser capped at ES 3.1 will reject the shaders.
* Rendering happens into an offscreen framebuffer that is read back with
  `glReadPixels` each frame. On the desktop this is the cost of presenting
  through X11 rather than a native surface.
* Only the CLI target is built. The upstream JNI entry point (`main.c`) is left
  out, as is the Android-only part of `libwinlator`; `sysvshared_memory` and
  `gpu_helper` are replaced by glibc equivalents inside the source tree.

## Source

Fork with the CLI changes: <https://github.com/as14725836/gladio-termux>

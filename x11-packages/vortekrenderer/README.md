# vortekrenderer

Vortek 渲染服务器（`vortekrenderer-cli`），在 Termux:X11 上为 Winlator / Wine
提供 Vulkan 兼容层。

## 这是什么

Vortek 采用「客户端 ICD + 服务端进程」的双进程结构：

| 组件 | 运行库 | 提供者 |
| --- | --- | --- |
| 客户端 ICD `libvulkan_vortek.so` | glibc | 上游 Release（`vortek-client-termux-glibc-aarch64.zip`） |
| **服务端 `vortekrenderer-cli`** | **bionic** | **本包** |

本包只包含**服务端**。客户端 ICD 是 glibc 构建，Wine 通过它把 Vulkan 调用
经 Unix socket 转发给本包，本包再用 GPU 驱动（经 libadrenotools 加载的
Adreno 驱动）真正执行渲染。

## 安装

```bash
pkg install vortekrenderer
```

同时需要配套的 glibc 客户端 ICD，从上游 Release 下载后解压：

```bash
# 下载 vortek-client-termux-glibc-aarch64.zip 并解压到某目录
export VK_ICD_FILENAMES=<解压目录>/share/vulkan/icd.d/vortek_icd.aarch64.json
```

## 使用

**必须先启动服务端**：客户端在 `vk_icdGetInstanceProcAddr()` 里就尝试连接，
如果服务端没起来，Vulkan loader 会把该 ICD 标记为无效（`Found no drivers!`），
并且**不会在同一进程内重试**。

```bash
vortekrenderer-cli -s "$PREFIX/tmp/.vortek/V0"
```

常见参数：

| 参数 | 说明 |
| --- | --- |
| `-s, --socket PATH` | Unix socket 路径，默认 `$PREFIX/tmp/.vortek/V0` |
| `-v, --libvulkan PATH` | 指定要加载的 Vulkan 驱动 |
| `--adrenotools-hook-dir DIR` | hook 库目录，默认自动探测 `$PREFIX/lib` |
| `--vk-version VER` | 上报给客户端的 Vulkan 版本 |
| `--once` | 只服务一个客户端后退出（便于调试） |
| `-h, --help` | 帮助 |

## 依赖与打包说明

- **运行时依赖**：`libandroid-shmem`、`libx11`、`libxcb`、`libxext`、
  `libxshmfence`。`libxcb` 单包已含 `dri3` / `present` / `sync` 扩展。
- **libadrenotools 与 hook 库**：上游 `server/libadrenotools` 随源码 vendored，
  本包在 `termux_step_pre_configure` 里先构建它。产出的 `libadrenotools.so`、
  `libhook_impl.so`、`libmain_hook.so` 都装进 `$PREFIX/lib`，这样
  `setDefaultAdrenotoolsHookDir()` 无需额外参数即可找到 hook。
- **patch 说明**：
  - `libadrenotools-CMakeLists.txt.patch` —— 上游用
    `if(NOT ${CMAKE_ANDROID_ARCH_ABI} STREQUAL arm64-v8a)` 做架构检查，而
    Termux 的 CMake 环境不设 `CMAKE_ANDROID_ARCH_ABI`，该条件会退化成
    `if(NOT STREQUAL arm64-v8a)` 并误报 `FATAL_ERROR`。改成只在变量显式存在
    且不匹配时才报错。
  - `vortekrenderer-CMakeLists.txt.patch` —— 上游 CMakeLists 用
    `set(CMAKE_C_FLAGS_RELEASE ...)` 覆盖了发行版传入的 release flags，
    会丢掉 `-fstack-protector-strong` 等加固选项；改为追加。
- **架构**：仅 `aarch64`（libadrenotools 只支持 arm64-v8a）。

## 零拷贝呈现（DRI3）

`VORTEK_CLI_X11=ON` 时服务端支持通过 Termux:X11 的 AHardwareBuffer socket
做零拷贝呈现。可用环境变量调试：

- `VORTEK_CLI_X11_DRI3` —— 强制启用 / 禁用 DRI3
- `VORTEK_CLI_X11_DRI3_DEBUG` —— 打印 DRI3 协商细节
- `VORTEK_CLI_X11_SHM` —— 强制走 XShm 回退路径

呈现按 DIRECT(AHB socket) → BLIT → XShm 三级回退。

## 上游

<https://github.com/as14725836/vortek-termux>

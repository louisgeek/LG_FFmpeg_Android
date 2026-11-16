# LG_FFmpeg_Android

Android 平台 FFmpeg 动态库编译脚本。

## 编译产物

| 架构 | 目录 | 内容 |
|------|------|------|
| arm64-v8a | `ffmpeg-output/arm64-v8a/` | `include/` + `lib/*.so` |
| armeabi-v7a | `ffmpeg-output/armeabi-v7a/` | `include/` + `lib/*.so` |
| x86 | `ffmpeg-output/x86/` | `include/` + `lib/*.so` |
| x86_64 | `ffmpeg-output/x86_64/` | `include/` + `lib/*.so` |

## 编译环境

```
Ubuntu 24.04.2
NDK: android-ndk-r27d (27.3.13750724)
FFmpeg: 7.1.5 LTS
Android API: 24 (Android 7.0 Nougat)
```

### NDK 下载

较新版本：https://developer.android.google.cn/ndk/downloads

较旧版本：https://github.com/android/ndk/wiki/Unsupported-Downloads

r27d 版本 ndkVersion `"27.3.13750724"`

```bash
mkdir AndroidDev
cd AndroidDev
wget https://dl.google.com/android/repository/android-ndk-r27d-linux.zip
unzip android-ndk-r27d-linux.zip
```

### FFmpeg 下载

https://ffmpeg.org/download.html

官网 Download 页面选 Download Source Code，或下方 More releases 里选 `ffmpeg-7.1.5`。

```bash
wget https://ffmpeg.org/releases/ffmpeg-7.1.5.tar.xz
tar -xf ffmpeg-7.1.5.tar.xz
```

## 编译

官方编译说明：https://trac.ffmpeg.org/wiki/CompilationGuide/Android

修改 `build_ffmpeg.sh` 顶部的 `NDK_PATH` 变量为你的实际 NDK 路径，然后执行：

```shell
chmod +x build_ffmpeg.sh
./build_ffmpeg.sh
```

默认编译后在 `ffmpeg-output/` 目录下生成不同平台的 `.so` 和 `include` 等文件。

## 配置说明

`build_ffmpeg.sh` 支持以下环境变量，可在运行脚本时覆盖默认值：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `NDK_PATH` | `$(pwd)/android-ndk-r27d` | NDK 安装路径 |
| `API_LEVEL` | `24` | 最小 Android API 级别 |
| `JOBS` | `$(nproc)` | 编译并行线程数 |
| `ENABLE_GPL` | `false` | 是否启用 GPL 组件（x264/x265） |
| `ENABLE_NONFREE` | `false` | 是否启用 nonfree 组件（fdk-aac） |

### 商业用途建议

- 保持 `ENABLE_GPL=false`，仅使用纯 **LGPL** 组件，避免 GPL 传染。
- 编译产物为动态库（`--enable-shared --disable-static`），符合 LGPL 要求，允许最终用户替换库文件。
- 禁用版本符号（使用 `--disable-symver`），生成无版本后缀的 `.so`，方便兼容性检查。

## 版本历史

- **7.1.5 LTS** — 当前版本，长期支持分支
- **6.1.4** — 旧版本，归档在 `archive/ffmpeg-6.1.4/`

## 许可证

FFmpeg 使用 LGPL 2.1+ 许可证。编译脚本和文档使用 MIT 许可证。

如需 GPL 组件（x264/x265/fdk-aac），请设置 `ENABLE_GPL=true`，并确保你的应用遵守 GPL 许可证要求。
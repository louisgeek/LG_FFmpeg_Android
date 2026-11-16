#!/usr/bin/env bash
# =============================================================================
# FFmpeg Android 编译脚本 - FFmpeg 7.1.5 LTS
# 遵循业界最佳实践，支持商业用途 (LGPL 合规)
# =============================================================================
# 设计原则:
#   1. 仅启用 LGPL 组件，避免 GPL 传染（如需 GPL 请取消注释 GPL 相关行）
#   2. 使用现代 NDK (r23+) 推荐的 --cross-prefix 方式，不再手动指定 CC/CXX/AR
#   3. 16KB page size 对齐 (-Wl,-z,max-page-size=16384)，满足 Android 15 / Google Play 要求
#   4. 动态库 (--enable-shared --disable-static)，便于最终用户替换库文件 (LGPL 要求)
#   5. 精简组件 (--enable-small --disable-doc --disable-ffmpeg/ffplay/ffprobe)
#   6. 禁用版本符号 (使用 --disable-symver)，生成无版本后缀的 .so
#   7. 支持 4 架构: arm64-v8a, armeabi-v7a, x86, x86_64
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 用户可配置变量 (修改此处即可，无需改动下方逻辑)
# -----------------------------------------------------------------------------
# NDK 路径 - 请修改为你的实际 NDK 路径
# 推荐: Android SDK 目录下的 ndk/27.x 或手动下载的 android-ndk-r27d
NDK_PATH="${NDK_PATH:-$(pwd)/android-ndk-r27d}"

# 最低 Android API 级别 (对应 minSdkVersion)
# API 24 = Android 7.0 (Nougat)，现代应用推荐 24+
API_LEVEL="${API_LEVEL:-24}"

# FFmpeg 源码版本
FFMPEG_VERSION="7.1.5"
FFMPEG_SRC_DIR="$(pwd)/ffmpeg-${FFMPEG_VERSION}"
FFMPEG_TARBALL="ffmpeg-${FFMPEG_VERSION}.tar.xz"
FFMPEG_URL="https://ffmpeg.org/releases/${FFMPEG_TARBALL}"

# 输出目录 (每架构独立的 include/ + lib/)
OUTPUT_BASE_DIR="$(pwd)/ffmpeg-output"

# 编译线程数 (默认使用所有 CPU 核心)
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

# 是否启用 GPL 组件 (x264, x265 等) - 商业用途请保持 false
ENABLE_GPL="${ENABLE_GPL:-false}"
# 是否启用 nonfree 组件 (fdk-aac 等) - 商业用途请保持 false
ENABLE_NONFREE="${ENABLE_NONFREE:-false}"

# -----------------------------------------------------------------------------
# 内部常量 (一般无需修改)
# -----------------------------------------------------------------------------
TOOLCHAIN="${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64"
HOST_TAG="linux-x86_64"

# 支持的架构配置: ARCH_CONFIG 用于 ./configure --arch
# 格式: "目录名|configure_arch|toolchain_prefix|cpu|extra_cflags"
ARCHS=(
    "arm64-v8a|aarch64|aarch64-linux-android|armv8-a|-fPIC"
    "armeabi-v7a|arm|armv7a-linux-androideabi|armv7-a|-fPIC -march=armv7-a -mfloat-abi=softfp -mfpu=neon"
    "x86|i686|i686-linux-android|i686|-fPIC -march=i686 -mtune=generic -msse2 -mfpmath=sse -m32"
    "x86_64|x86_64|x86_64-linux-android|x86-64|-fPIC -march=x86-64 -mtune=generic -msse4.2 -mpopcnt -m64"
)

# 通用 configure 选项 (LGPL 合规的核心组件)
COMMON_CONFIGURE_FLAGS=(
    --target-os=android
    --enable-cross-compile
    --cross-prefix="${TOOLCHAIN}/bin/"
    --sysroot="${TOOLCHAIN}/sysroot"
    --enable-shared
    --disable-static
    --disable-doc
    --disable-ffmpeg
    --disable-ffplay
    --disable-ffprobe
    --disable-symver
    --enable-small
    --enable-jni
    --enable-mediacodec
    --disable-vulkan
    --disable-debug
    --disable-stripping
    --enable-pic
    # 核心解码器 (LGPL 安全)
    --enable-decoder=h264,hevc,mpeg4,mjpeg,vp8,vp9,aac,mp3,opus,vorbis,flac,pcm*
    # 核心编码器 (LGPL 安全: libx264/libx265 需 GPL，此处仅内建)
    --enable-encoder=h264,hevc,mpeg4,mjpeg,aac,mp3,pcm*
    --enable-parser=h264,hevc,mpeg4video,mjpeg,vp8,vp9,aac,mp3,opus,flac
    --enable-demuxer=h264,hevc,matroska,mov,mpegts,mp3,flv,ogg,wav,mp4
    --enable-muxer=mp4,mov,matroska,mpegts,mp3,flv,ogg,wav
    # 常用滤镜
    --enable-filter=scale,crop,resample,transpose,rotate,overlay,eq,brightness,contrast,saturation,hue,colorchannelmixer,volume,aresample,format
    --enable-bsf=h264_mp4toannexb,hevc_mp4toannexb,aac_adtstoasc,mp3_header_decompress
    --enable-protocol=file,http,https,tcp,tls,rtmp,rtmps
    --enable-indev=lavfi
    --enable-outdev=lavfi
    # 网络相关 (LGPL)
    --enable-network
    # 硬件加速 (Android MediaCodec)
    --enable-hwaccel=h264_mediacodec,hevc_mediacodec,mpeg4_mediacodec,vp8_mediacodec,vp9_mediacodec
    --enable-decoder=h264_mediacodec,hevc_mediacodec,mpeg4_mediacodec,vp8_mediacodec,vp9_mediacodec
)

# GPL 组件 (需要 ENABLE_GPL=true 才启用)
GPL_CONFIGURE_FLAGS=(
    --enable-gpl
    --enable-version3
    --enable-libx264
    --enable-libx265
    --enable-encoder=libx264,libx265
)

# Nonfree 组件 (需要 ENABLE_NONFREE=true 且 ENABLE_GPL=true)
NONFREE_CONFIGURE_FLAGS=(
    --enable-nonfree
    --enable-libfdk-aac
    --enable-encoder=libfdk_aac
)

# -----------------------------------------------------------------------------
# 辅助函数
# -----------------------------------------------------------------------------
log_info() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

check_prerequisites() {
    log_info "检查编译环境..."
    [[ -d "${NDK_PATH}" ]] || { log_error "NDK 不存在: ${NDK_PATH}"; exit 1; }
    [[ -f "${TOOLCHAIN}/bin/aarch64-linux-android${API_LEVEL}-clang" ]] || {
        log_error "找不到 aarch64 编译器，请检查 NDK_PATH 和 API_LEVEL"; exit 1; }
    command -v make >/dev/null || { log_error "未安装 make"; exit 1; }
    command -v tar >/dev/null || { log_error "未安装 tar"; exit 1; }
    command -v curl >/dev/null || command -v wget >/dev/null || { log_error "需要 curl 或 wget 下载源码"; exit 1; }
    log_info "环境检查通过: NDK=${NDK_PATH}, API=${API_LEVEL}, JOBS=${JOBS}"
}

download_ffmpeg() {
    if [[ -d "${FFMPEG_SRC_DIR}" ]]; then
        log_info "源码目录已存在: ${FFMPEG_SRC_DIR}，跳过下载"
        return
    fi
    if [[ ! -f "${FFMPEG_TARBALL}" ]]; then
        log_info "下载 FFmpeg ${FFMPEG_VERSION} 源码..."
        if command -v curl >/dev/null; then
            curl -L -o "${FFMPEG_TARBALL}" "${FFMPEG_URL}"
        else
            wget -O "${FFMPEG_TARBALL}" "${FFMPEG_URL}"
        fi
    fi
    log_info "解压源码..."
    tar -xf "${FFMPEG_TARBALL}"
    log_info "源码准备完成: ${FFMPEG_SRC_DIR}"
}

build_arch() {
    local arch_entry="$1"
    IFS='|' read -r ARCH_DIR ARCH_CONFIG TOOLCHAIN_PREFIX CPU EXTRA_CFLAGS <<<"${arch_entry}"

    log_info "==================== 编译 ${ARCH_DIR} (arch=${ARCH_CONFIG}, cpu=${CPU}) ===================="

    local ARCH_OUTPUT_DIR="${OUTPUT_BASE_DIR}/${ARCH_DIR}"
    mkdir -p "${ARCH_OUTPUT_DIR}"

    cd "${FFMPEG_SRC_DIR}"

    # 组装 configure 参数
    local configure_flags=("${COMMON_CONFIGURE_FLAGS[@]}")
    configure_flags+=(
        --prefix="${ARCH_OUTPUT_DIR}"
        --arch="${ARCH_CONFIG}"
        --cpu="${CPU}"
        --extra-cflags="${EXTRA_CFLAGS}"
        --extra-ldflags="-Wl,-z,max-page-size=16384"
    )

    # 条件启用 GPL / Nonfree
    if [[ "${ENABLE_GPL}" == "true" ]]; then
        log_warn "启用 GPL 组件 (--enable-gpl, --enable-version3, --enable-libx264, --enable-libx265)"
        configure_flags+=("${GPL_CONFIGURE_FLAGS[@]}")
        if [[ "${ENABLE_NONFREE}" == "true" ]]; then
            log_warn "启用 Nonfree 组件 (--enable-nonfree, --enable-libfdk-aac)"
            configure_flags+=("${NONFREE_CONFIGURE_FLAGS[@]}")
        fi
    else
        log_info "使用纯 LGPL 配置 (无 GPL/Nonfree 组件)，商业用途安全"
    fi

    log_info "执行 configure..."
    ./configure "${configure_flags[@]}"

    log_info "编译中 (make -j${JOBS})..."
    make clean
    make -j"${JOBS}"
    make install

    log_info "${ARCH_DIR} 完成: ${ARCH_OUTPUT_DIR}"
}

create_summary() {
    log_info "==================== 编译摘要 ===================="
    for arch_entry in "${ARCHS[@]}"; do
        IFS='|' read -r ARCH_DIR _ _ _ _ <<<"${arch_entry}"
        echo "架构 ${ARCH_DIR}:"
        if [[ -d "${OUTPUT_BASE_DIR}/${ARCH_DIR}/lib" ]]; then
            ls -lh "${OUTPUT_BASE_DIR}/${ARCH_DIR}/lib/"*.so 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
        else
            echo "  (未找到输出)"
        fi
    done
    echo ""
    log_info "头文件位于: \${OUTPUT_BASE_DIR}/<arch>/include/"
    log_info "库文件位于: \${OUTPUT_BASE_DIR}/<arch>/lib/"
    log_info ""
    log_info "=== LGPL 合规提示 ==="
    log_info "1. 仅编译了动态库 (.so)，允许最终用户替换库文件"
    log_info "2. 已启用 --disable-symver，生成无版本后缀的 .so，方便兼容性检查"
    log_info "3. 未包含 GPL 组件 (x264/x265/fdk-aac)，如需请设置 ENABLE_GPL=true"
    log_info "4. 请随应用提供 FFmpeg 源码或书面获取源码的方式 (LGPL 要求)"
}

# -----------------------------------------------------------------------------
# 主流程
# -----------------------------------------------------------------------------
main() {
    log_info "================================================================="
    log_info "FFmpeg ${FFMPEG_VERSION} Android 编译开始"
    log_info "NDK: ${NDK_PATH}"
    log_info "API Level: ${API_LEVEL}"
    log_info "输出目录: ${OUTPUT_BASE_DIR}"
    log_info "GPL 组件: ${ENABLE_GPL}"
    log_info "Nonfree 组件: ${ENABLE_NONFREE}"
    log_info "================================================================="

    check_prerequisites
    download_ffmpeg

    for arch_entry in "${ARCHS[@]}"; do
        build_arch "${arch_entry}"
    done

    create_summary

    log_info "================================================================="
    log_info "所有架构编译完成！"
    log_info "================================================================="
}

# 允许作为库被 source 调用，也可直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
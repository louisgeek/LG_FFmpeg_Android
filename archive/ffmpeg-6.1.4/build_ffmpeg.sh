#!/bin/bash

# FFmpeg Android 编译脚本

# 配置参数
NDK_PATH=$(pwd)/android-ndk-r27d
API_LEVEL=24 # MIN_SDK_VERSION
TOOLCHAIN=$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64
FFMPEG_SRC_DIR=$(pwd)/ffmpeg-6.1.4
OUTPUT_DIR=$(pwd)/ffmpeg-output

echo "开始编译 FFmpeg for Android..."
echo "NDK_PATH: $NDK_PATH"
echo "API_LEVEL $API_LEVEL"
echo "FFMPEG_SRC_DIR: $FFMPEG_SRC_DIR"
echo "OUTPUT_DIR: $OUTPUT_DIR"
echo ""

# 检查NDK路径
if [ ! -d "$NDK_PATH" ]; then
    echo "错误: 找不到 Android NDK: $NDK_PATH"
    exit 1
fi

# 检查编译工具
if [ ! -f "$TOOLCHAIN/bin/aarch64-linux-android$API_LEVEL-clang" ]; then
    echo "错误: 找不到编译器: $TOOLCHAIN/bin/aarch64-linux-android$API_LEVEL-clang"
    exit 1
fi

cd "$FFMPEG_SRC_DIR"

# 支持的架构
ARCHS=('arm64-v8a' 'armeabi-v7a' 'x86' 'x86_64')
# ARCHS=('arm64-v8a' 'armeabi-v7a')

# 循环编译不同架构
for ARCH in "${ARCHS[@]}"; do
    echo "编译 $ARCH 架构..."
    
    # 设置编译参数
    if [ "$ARCH" = "arm64-v8a" ]; then
        TARGET_HOST=aarch64-linux-android
        CC=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang
        CXX=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang++
        AR=$TOOLCHAIN/bin/llvm-ar
        AS=$TOOLCHAIN/bin/$TARGET_HOST-as
        LD=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang
        NM=$TOOLCHAIN/bin/llvm-nm
        RANLIB=$TOOLCHAIN/bin/llvm-ranlib
        STRIP=$TOOLCHAIN/bin/llvm-strip
        CFLAGS="-fPIC"
        LDFLAGS=""
        ARCH_CONFIG="aarch64"
    elif [ "$ARCH" = "armeabi-v7a" ]; then
        TARGET_HOST=armv7a-linux-androideabi
        CC=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang
        CXX=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang++
        AR=$TOOLCHAIN/bin/llvm-ar
        AS=$TOOLCHAIN/bin/$TARGET_HOST-as
        LD=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang
        NM=$TOOLCHAIN/bin/llvm-nm
        RANLIB=$TOOLCHAIN/bin/llvm-ranlib
        STRIP=$TOOLCHAIN/bin/llvm-strip
        CFLAGS="-fPIC -march=armv7-a -mfloat-abi=softfp -mfpu=neon"
        LDFLAGS=""
        ARCH_CONFIG="arm"
    elif [ "$ARCH" = "x86" ]; then
        TARGET_HOST=i686-linux-android
        CC=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang
        CXX=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang++
        AR=$TOOLCHAIN/bin/llvm-ar
        AS=$TOOLCHAIN/bin/$TARGET_HOST-as
        LD=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang
        NM=$TOOLCHAIN/bin/llvm-nm
        RANLIB=$TOOLCHAIN/bin/llvm-ranlib
        STRIP=$TOOLCHAIN/bin/llvm-strip
        CFLAGS="-fPIC -march=i686 -mtune=generic -msse2 -mfpmath=sse -m32"
        LDFLAGS=""
        ARCH_CONFIG="i386"
    elif [ "$ARCH" = "x86_64" ]; then
        TARGET_HOST=x86_64-linux-android
        CC=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang
        CXX=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang++
        AR=$TOOLCHAIN/bin/llvm-ar
        AS=$TOOLCHAIN/bin/$TARGET_HOST-as
        LD=$TOOLCHAIN/bin/$TARGET_HOST$API_LEVEL-clang
        NM=$TOOLCHAIN/bin/llvm-nm
        RANLIB=$TOOLCHAIN/bin/llvm-ranlib
        STRIP=$TOOLCHAIN/bin/llvm-strip
        CFLAGS="-fPIC -march=x86-64 -mtune=generic -msse4.2 -mpopcnt -m64"
        LDFLAGS=""
        ARCH_CONFIG="x86_64"
    fi
    
    # 创建输出目录
    ARCH_OUTPUT_DIR="$OUTPUT_DIR/$ARCH"
    
    mkdir -p "$ARCH_OUTPUT_DIR"
    
    echo "使用编译器: $CC"
    
    # FFmpeg 配置
    ./configure \
        --prefix="$ARCH_OUTPUT_DIR" \
        --target-os=android \
        --arch=$ARCH_CONFIG \
        --cpu=generic \
        --enable-cross-compile \
        --cross-prefix="" \
        --cc=$CC \
        --cxx=$CXX \
        --ar=$AR \
        --as=$AS \
        --ld=$LD \
        --nm=$NM \
        --ranlib=$RANLIB \
        --strip=$STRIP \
        --enable-shared \
        --disable-static \
        --disable-doc \
        --enable-small \
        --disable-ffmpeg \
        --disable-ffplay \
        --disable-ffprobe \
        --disable-symver \
        --enable-jni \
        --enable-mediacodec \
        --disable-vulkan \
        --enable-decoder=h264,hevc,mpeg4,mjpeg,vp8,vp9,aac,mp3,opus \
        --enable-encoder=h264,hevc,mpeg4,mjpeg,aac,mp3 \
        --enable-parser=h264,h264_mp4toannexb,aac,mpeg4video,mjpeg,vp8,vp9 \
        --enable-demuxer=h264,matroska,mov,mpegts,mp3,flv \
        --enable-muxer=mp4,mov,matroska,mpegts,mp3,flv \
        --enable-filter=scale,crop,resample,transpose,rotate,overlay,eq,brightness,contrast,saturation,hue,colorchannelmixer,volume,aresample \
        --enable-bsf=h264_mp4toannexb,hevc_mp4toannexb,aac_adtstoasc \
        --enable-protocol=file,http,https,tcp,tls \
        --enable-indev=lavfi \
        --disable-x86asm \
        --disable-asm \
   	--extra-cflags="$CFLAGS" \
    	--extra-ldflags="$LDFLAGS -Wl,-z,max-page-size=16384" # NDK r27 版本对应的 16 KB 配置
    
    # 检查 configure 是否成功
    CONFIG_STATUS=$?
    if [ $CONFIG_STATUS -ne 0 ]; then
        echo "配置失败，退出编译。错误代码: $CONFIG_STATUS"
        if [ -f "ffbuild/config.log" ]; then
            tail -n 50 ffbuild/config.log
        fi
        exit 1
    fi
    
    # 编译并安装
    make clean
    make -j$(nproc)
    MAKE_STATUS=$?
    if [ $MAKE_STATUS -eq 0 ]; then
        make install
        echo "$ARCH 架构编译完成"
    else
        echo "$ARCH 架构编译失败。错误代码: $MAKE_STATUS"
        exit 1
    fi

done

echo "FFmpeg 编译完成！库文件位于: $OUTPUT_DIR"

# 创建库文件信息摘要
echo -e "\n编译的库文件摘要:"
for ARCH in "${ARCHS[@]}"; do
    echo "架构 $ARCH:"
    ls -la $OUTPUT_DIR/$ARCH/lib/ | grep so
done


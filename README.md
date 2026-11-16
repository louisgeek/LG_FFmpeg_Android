# LG_FFmpeg_Android



## 编译环境

```
Ubuntu
ubuntu-24.04.2-desktop-amd64

NDK
android-ndk-r27d-linux.zip

ffmpeg
ffmpeg-6.1.4.tar.xz
```



## NDK 下载

较新版本

https://developer.android.google.cn/ndk/downloads

较旧版本

https://github.com/android/ndk/wiki/Unsupported-Downloads 

r27d 版本 ndkVersion "27.3.13750724"

https://dl.google.com/android/repository/android-ndk-r27d-linux.zip



```
mkdir AndroidDev
cd AndroidDev
wget https://dl.google.com/android/repository/android-ndk-r27d-linux.zip
unzip android-ndk-r27d-linux.zip
```



## ffmpeg 下载

https://ffmpeg.org/download.html

官网 Download 页面代码，选 Download Source Code 或下方 More releases 里选 ffmpeg-6.1.4 版本



或者直接下载解压

```
wget https://ffmpeg.org/releases/ffmpeg-6.1.4.tar.xz
tar -xf ffmpeg-6.1.4.tar.xz
```



## 编译

官方编译说明

```
https://trac.ffmpeg.org/wiki/CompilationGuide/Android
```

修改 build_ffmpeg.sh 脚本，指定正确的 NDK_PATH 等路径，然后执行命令

```shell
# 赋予脚本执行权限
chmod +x build_ffmpeg.sh
# 运行脚本编译
./build_ffmpeg.sh
```



默认编译后在 ffmpeg-output 目录下生成不同平台的 .so 和 include 等文件

```
/home/louis/AndroidDev/ffmpeg-output/armeabi-v7a
/home/louis/AndroidDev/ffmpeg-output/arm64-v8a
/home/louis/AndroidDev/ffmpeg-output/x86
/home/louis/AndroidDev/ffmpeg-output/x86_64
```



说明

```
//6.1.4 源码
ffmpeg-6.1.4.tar.xz
//编译后生成的文件
ffmpeg-output.7z
//编译后生成的文件里的 so 库和 include 文件
armeabi-v7a arm64-v8a x86 x86_64
```











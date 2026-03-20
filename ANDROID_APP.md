# Android APK 方案

这个项目已经附带一个最小可用的 Android 壳工程，目录在：

`/android`

它的功能很简单：

- 用 WebView 打开你的 Flask 页面
- 默认访问 `http://127.0.0.1:5000`
- 可在 App 菜单里修改服务地址
- 修改后会保存到本地，下次继续使用

## 为什么默认地址不一定能直接用

如果 Flask 服务跑在你电脑上，安卓手机里的 `127.0.0.1` 指向的是手机自己，不是你的电脑。

通常你应该填：

- 电脑局域网 IP，例如 `http://192.168.1.10:5000`
- 或者公网服务器地址

只有在这两种情况可以用 `127.0.0.1`：

- Flask 服务就跑在安卓设备本机
- 你自己做了端口转发

## 怎么生成 APK

当前仓库已经有 Android 工程，但这个环境里没有 Android SDK/Gradle，所以我没法直接在这里产出 APK。

如果你不想在本机安装 Android SDK，可以直接走 GitHub Actions 云编译，说明见：

`/GITHUB_ACTIONS_ANDROID.md`

你可以在自己的电脑上这样做：

1. 安装 Android Studio
2. 打开目录：`D:\codebuddyTest\android`
3. 等 Android Studio 自动同步 Gradle
4. 连接手机或创建模拟器
5. 点击 `Build > Build APK(s)` 生成 APK

生成位置通常在：

`android/app/build/outputs/apk/debug/app-debug.apk`

## 首次使用

1. 先启动 Flask 服务
2. 确保手机和服务端在同一网络，或服务可公网访问
3. 安装 APK
4. 打开 App
5. 右上角菜单里点“修改服务地址”
6. 填入实际地址，例如 `http://192.168.1.10:5000`

## 目录说明

- `android/app/src/main/java/com/regicems/app/MainActivity.java`
- `android/app/src/main/res/layout/activity_main.xml`
- `android/app/src/main/AndroidManifest.xml`

如果你要，我下一步可以继续做两件事：

1. 给这个 Android 壳 App 增加“设置页”而不是菜单弹窗
2. 再补一个可离线图标、启动页和签名打包说明

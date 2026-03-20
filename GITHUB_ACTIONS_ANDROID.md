# GitHub Actions 云编译 APK

这个仓库已经加好了 GitHub Actions 工作流：

`/.github/workflows/android-apk.yml`

它会做这些事：

1. 拉取代码
2. 安装 JDK 17
3. 安装 Android SDK
4. 编译 Android debug APK
5. 把 APK 作为构建产物上传

## 你要做什么

### 1. 把项目上传到 GitHub

如果还没有远程仓库，可以这样做：

```bash
git init
git add .
git commit -m "init regice-ms"
git branch -M main
git remote add origin <你的仓库地址>
git push -u origin main
```

如果仓库已经有了，只要把当前改动推上去：

```bash
git add .
git commit -m "add android github actions build"
git push
```

## 2. 去 GitHub 页面触发构建

打开你的 GitHub 仓库页面，然后：

1. 点击顶部 `Actions`
2. 左侧找到 `Build Android APK`
3. 点击它
4. 点击 `Run workflow`
5. 再点击弹出的 `Run workflow`

如果你把代码推到 `main` 或 `master`，这个工作流也会自动跑。

## 3. 下载 APK

构建完成后：

1. 进入这次工作流运行详情
2. 页面底部找到 `Artifacts`
3. 下载 `regice-ms-debug-apk`
4. 解压后拿到：

`app-debug.apk`

这就是你可以安装到手机上的 APK。

## 4. 手机上怎么用

安装 APK 后：

1. 打开 App
2. 点右上角菜单
3. 选择“修改服务地址”
4. 填你的 Flask 服务地址

例如：

- 同一局域网电脑：`http://192.168.1.10:5000`
- 服务器地址：`http://你的服务器IP:5000`

不要默认填 `127.0.0.1:5000`，因为手机里的 `127.0.0.1` 指向手机自己，不是你的电脑。

## 当前产物说明

现在工作流构建的是：

- `debug APK`

优点：

- 不需要你先配置签名
- 最容易先跑通

限制：

- 适合测试安装
- 不适合正式上架应用市场

## 后面如果你想做正式发布

我下一步可以继续帮你补：

1. `release` 签名配置
2. GitHub Secrets 管理签名文件
3. 自动输出正式 APK 或 AAB

这样你后面就不只是能测试安装，而是能走正式发布流程。

# GitHub Actions APK 打包配置

## 前置条件

要使 GitHub Actions 能够自动打包 APK，需要配置以下 Secrets。

## 配置步骤

1. 进入 GitHub 仓库 → Settings → Secrets and variables → Actions
2. 添加以下 Secrets：

### 必需的 Secrets

#### 1. ANDROID_KEYSTORE_BASE64
- **说明**：Android 签名密钥库的 Base64 编码
- **获取方法**：
  ```bash
  base64 -i android/app/upload-keystore.jks -o keystore.txt
  ```
  或在 Windows PowerShell：
  ```powershell
  [Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/upload-keystore.jks")) | Set-Clipboard
  ```
- **值**：复制生成的 Base64 字符串

#### 2. ANDROID_STORE_PASSWORD
- **说明**：Keystore 的密码
- **值**：你的 keystore 密码

#### 3. ANDROID_KEY_ALIAS
- **说明**：密钥别名
- **值**：通常是 `upload` 或你设置的别名

#### 4. ANDROID_KEY_PASSWORD
- **说明**：密钥密码
- **值**：你的密钥密码

## 工作流触发

工作流会在以下情况自动触发：

- 推送到 `main` 或 `master` 分支
- 修改以下文件时：
  - `lib/**`
  - `android/**`
  - `pubspec.yaml`
  - `analysis_options.yaml`
  - `.github/workflows/android-apk.yml`

也可以手动触发：
1. 进入 GitHub 仓库 → Actions
2. 选择 "Android APK" 工作流
3. 点击 "Run workflow"

## 输出

构建成功后，APK 文件会作为 artifact 上传，名称为 `regice-ms-release-apk`。

## 故障排除

### 构建失败

检查以下几点：

1. **Secrets 配置是否正确**
   - 确保所有 4 个 Secrets 都已设置
   - 检查 Base64 编码是否正确

2. **Flutter 版本**
   - 当前使用 Flutter 3.41.6
   - 如需更新，修改 `.github/workflows/android-apk.yml` 中的 `FLUTTER_VERSION`

3. **Java 版本**
   - 当前使用 Java 17
   - 与本地开发环境保持一致

### 签名问题

如果没有配置 Secrets，APK 会使用 debug 签名。要使用 release 签名：

1. 确保所有 4 个 Secrets 都已正确配置
2. 重新运行工作流

## 本地测试

在本地测试 APK 打包：

```bash
flutter build apk --release
```

输出文件：`build/app/outputs/flutter-apk/app-release.apk`

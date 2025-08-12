# 构建脚本使用指南

## 快速开始

### 方法一：使用批处理脚本（推荐新手）
双击运行 `build.bat`，然后按照菜单选择相应的构建选项。

### 方法二：使用 PowerShell 脚本（推荐开发者）

```powershell
# 构建所有平台
.\build_release.ps1 -All

# 只构建 Android APK
.\build_release.ps1 -Android

# 只构建 Windows 应用
.\build_release.ps1 -Windows

# 清理缓存后构建所有平台
.\build_release.ps1 -Clean -All
```

### 方法三：手动构建

```bash
# Android APK
flutter build apk --release --split-per-abi

# Windows 应用
flutter build windows --release
```

## 输出文件位置

构建完成后，所有文件将输出到 `release/` 目录：

```
release/
├── android/
│   ├── http_proxy_speed_test_v1.0.0_app-arm64-v8a-release.apk
│   ├── http_proxy_speed_test_v1.0.0_app-armeabi-v7a-release.apk
│   └── http_proxy_speed_test_v1.0.0_app-x86_64-release.apk
└── windows/
    ├── http_proxy_speed_test_v1.0.0_windows/
    └── http_proxy_speed_test_v1.0.0_windows.zip
```

## 系统要求

- Flutter SDK 3.22.2+
- Android SDK (用于 Android 构建)
- Visual Studio 2022 with C++ (用于 Windows 构建)
- PowerShell 5.0+ (Windows)

## 常见问题

### Q: PowerShell 执行策略错误
A: 运行以下命令设置执行策略：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Q: Android 构建失败
A: 确保已安装 Android SDK 并设置了正确的环境变量：
- `ANDROID_HOME`
- `ANDROID_SDK_ROOT`

### Q: Windows 构建失败
A: 确保已安装 Visual Studio 2022 并包含 C++ 工具链。

## 自动化构建

项目已配置 GitHub Actions，推送标签时将自动构建并发布到 Releases：

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 自定义配置

可以在 `build_release.ps1` 中修改以下配置：
- 输出目录路径
- 文件命名格式
- 构建参数
- 压缩选项

# HTTP Proxy Speed Test 构建脚本
# 作者: GitHub Copilot
# 日期: 2025-08-12

param(
    [switch]$Android,
    [switch]$Windows,
    [switch]$All,
    [switch]$Clean
)

# 设置控制台编码为 UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 颜色输出函数
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# 检查 Flutter 是否安装
function Test-Flutter {
    try {
        $flutterVersion = flutter --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✓ Flutter 已安装" "Green"
            return $true
        }
    }
    catch {
        Write-ColorOutput "✗ Flutter 未安装或不在 PATH 中" "Red"
        return $false
    }
    return $false
}

# 清理构建缓存
function Clear-BuildCache {
    Write-ColorOutput "🧹 清理构建缓存..." "Yellow"
    
    if (Test-Path "build") {
        Remove-Item -Recurse -Force "build"
        Write-ColorOutput "✓ 删除 build 目录" "Green"
    }
    
    flutter clean
    Write-ColorOutput "✓ Flutter 缓存已清理" "Green"
    
    flutter pub get
    Write-ColorOutput "✓ 依赖包已重新获取" "Green"
}

# 构建 Android APK
function Build-AndroidAPK {
    Write-ColorOutput "📱 开始构建 Android APK..." "Cyan"
    
    # 创建输出目录
    $outputDir = "release\android"
    if (!(Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # 构建 APK
    Write-ColorOutput "构建 Release APK..." "Yellow"
    flutter build apk --release --split-per-abi
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Android APK 构建成功!" "Green"
        
        # 复制 APK 文件到 release 目录
        $apkFiles = Get-ChildItem -Path "build\app\outputs\flutter-apk" -Filter "*.apk"
        foreach ($apk in $apkFiles) {
            $newName = "http_proxy_speed_test_v1.0.0_$($apk.BaseName).apk"
            Copy-Item -Path $apk.FullName -Destination "$outputDir\$newName"
            Write-ColorOutput "📦 复制: $newName" "Green"
        }
        
        # 显示 APK 信息
        Write-ColorOutput "`n📋 APK 信息:" "Cyan"
        foreach ($apk in $apkFiles) {
            $size = [math]::Round((Get-Item $apk.FullName).Length / 1MB, 2)
            Write-ColorOutput "   $($apk.Name) - ${size}MB" "White"
        }
        
        return $true
    }
    else {
        Write-ColorOutput "✗ Android APK 构建失败!" "Red"
        return $false
    }
}

# 构建 Windows 应用
function Build-WindowsApp {
    Write-ColorOutput "🖥️ 开始构建 Windows 应用..." "Cyan"
    
    # 创建输出目录
    $outputDir = "release\windows"
    if (!(Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # 构建 Windows 应用
    Write-ColorOutput "构建 Windows Release..." "Yellow"
    flutter build windows --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Windows 应用构建成功!" "Green"
        
        # 复制文件到 release 目录
        $sourceDir = "build\windows\x64\runner\Release"
        $targetDir = "$outputDir\http_proxy_speed_test_v1.0.0_windows"
        
        if (Test-Path $targetDir) {
            Remove-Item -Recurse -Force $targetDir
        }
        
        Copy-Item -Path $sourceDir -Destination $targetDir -Recurse
        Write-ColorOutput "📦 复制到: $targetDir" "Green"
        
        # 创建压缩包
        $zipPath = "$outputDir\http_proxy_speed_test_v1.0.0_windows.zip"
        if (Test-Path $zipPath) {
            Remove-Item $zipPath
        }
        
        Compress-Archive -Path $targetDir -DestinationPath $zipPath
        Write-ColorOutput "📦 创建压缩包: $zipPath" "Green"
        
        # 显示文件大小
        $exeSize = [math]::Round((Get-Item "$targetDir\http_proxy_speed_test.exe").Length / 1MB, 2)
        $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
        
        Write-ColorOutput "`n📋 Windows 应用信息:" "Cyan"
        Write-ColorOutput "   可执行文件: ${exeSize}MB" "White"
        Write-ColorOutput "   压缩包: ${zipSize}MB" "White"
        
        return $true
    }
    else {
        Write-ColorOutput "✗ Windows 应用构建失败!" "Red"
        return $false
    }
}

# 显示帮助信息
function Show-Help {
    Write-ColorOutput "`n🚀 HTTP Proxy Speed Test 构建脚本" "Cyan"
    Write-ColorOutput "用法:" "Yellow"
    Write-ColorOutput "  .\build_release.ps1 -All           # 构建所有平台" "White"
    Write-ColorOutput "  .\build_release.ps1 -Android       # 只构建 Android APK" "White"
    Write-ColorOutput "  .\build_release.ps1 -Windows       # 只构建 Windows 应用" "White"
    Write-ColorOutput "  .\build_release.ps1 -Clean         # 清理构建缓存" "White"
    Write-ColorOutput "  .\build_release.ps1 -Clean -All    # 清理后构建所有平台" "White"
    Write-ColorOutput ""
}

# 主程序
function Main {
    Write-ColorOutput "🚀 HTTP Proxy Speed Test 构建脚本" "Cyan"
    Write-ColorOutput "============================================" "Cyan"
    
    # 检查参数
    if (-not ($Android -or $Windows -or $All -or $Clean)) {
        Show-Help
        return
    }
    
    # 检查 Flutter
    if (-not (Test-Flutter)) {
        Write-ColorOutput "请先安装 Flutter 并确保其在 PATH 中" "Red"
        return
    }
    
    # 清理缓存
    if ($Clean) {
        Clear-BuildCache
        Write-ColorOutput ""
    }
    
    # 记录开始时间
    $startTime = Get-Date
    $success = $true
    
    # 创建 release 目录
    if (!(Test-Path "release")) {
        New-Item -ItemType Directory -Path "release" -Force | Out-Null
    }
    
    # 构建 Android
    if ($Android -or $All) {
        if (-not (Build-AndroidAPK)) {
            $success = $false
        }
        Write-ColorOutput ""
    }
    
    # 构建 Windows
    if ($Windows -or $All) {
        if (-not (Build-WindowsApp)) {
            $success = $false
        }
        Write-ColorOutput ""
    }
    
    # 显示总结
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-ColorOutput "============================================" "Cyan"
    if ($success) {
        Write-ColorOutput "🎉 构建完成! 用时: $($duration.ToString('mm\:ss'))" "Green"
        Write-ColorOutput "📁 输出目录: release\" "Green"
    }
    else {
        Write-ColorOutput "❌ 构建过程中出现错误!" "Red"
    }
    
    # 显示输出文件
    if (Test-Path "release") {
        Write-ColorOutput "`n📦 构建产物:" "Cyan"
        Get-ChildItem -Path "release" -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Replace((Get-Location).Path + "\", "")
            $size = [math]::Round($_.Length / 1MB, 2)
            Write-ColorOutput "   $relativePath (${size}MB)" "White"
        }
    }
}

# 运行主程序
Main

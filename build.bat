@echo off
chcp 65001 >nul
echo.
echo 🚀 HTTP Proxy Speed Test 快速构建脚本
echo ========================================
echo.
echo 选择构建选项:
echo [1] 构建 Android APK
echo [2] 构建 Windows 应用
echo [3] 构建所有平台
echo [4] 清理缓存后构建所有平台
echo [0] 退出
echo.
set /p choice=请选择 (0-4): 

if "%choice%"=="1" (
    echo.
    echo 📱 构建 Android APK...
    powershell -ExecutionPolicy Bypass -File "build_release.ps1" -Android
) else if "%choice%"=="2" (
    echo.
    echo 🖥️ 构建 Windows 应用...
    powershell -ExecutionPolicy Bypass -File "build_release.ps1" -Windows
) else if "%choice%"=="3" (
    echo.
    echo 🏗️ 构建所有平台...
    powershell -ExecutionPolicy Bypass -File "build_release.ps1" -All
) else if "%choice%"=="4" (
    echo.
    echo 🧹 清理缓存后构建所有平台...
    powershell -ExecutionPolicy Bypass -File "build_release.ps1" -Clean -All
) else if "%choice%"=="0" (
    echo 再见！
    exit /b 0
) else (
    echo 无效选择！
    pause
    goto :eof
)

echo.
echo 按任意键继续...
pause >nul

@echo off
setlocal enabledelayedexpansion

REM Build script for Flutter flavors - Single command to change icon and build APK
REM Builds for Android 13+ only (arm64-v8a architecture) for optimal APK size
REM Usage: build.bat {flavor}
REM Example: build.bat tradoxy

if "%~1"=="" (
    echo Error: Missing flavor argument
    echo Usage: build.bat {flavor}
    echo   flavor: afx, pipze, onsa, tenax, profx, tradoxy
    echo.
    echo Example: build.bat tradoxy
    echo.
    echo Note: Building for Android 13+ only (arm64-v8a) for optimal APK size
    pause
    exit /b 1
)

set FLAVOR=%~1

echo ========================================
echo Building !FLAVOR! - Release APK
echo Target: Android 13+ (arm64-v8a only)
echo ========================================
echo.

REM Step 1: Prepare assets (changes app icon, splash, etc.)
echo [Step 1/2] Preparing client assets...
echo - Copying assets
echo - Generating launcher icons (app icon)
echo - Generating splash screen
echo.
call dart run scripts/prepare_flavor.dart !FLAVOR!
if errorlevel 1 (
    echo.
    echo ERROR: Failed to prepare assets
    pause
    exit /b 1
)

echo.
echo [Step 1/2] COMPLETED - Assets prepared!
echo App launcher icon has been changed!
echo.

REM Step 2: Build Release APK (arm64-v8a only for Android 13+)
echo [Step 2/2] Building Release APK (arm64-v8a only)...
echo This will take several minutes, please wait...
echo.
call flutter build apk --flavor !FLAVOR! -t lib/main.dart --dart-define=FLAVOR=!FLAVOR! --release --target-platform android-arm64

if errorlevel 1 (
    echo.
    echo ERROR: Build failed
    pause
    exit /b 1
)

REM Show result
echo.
echo ========================================
echo BUILD COMPLETED SUCCESSFULLY!
echo ========================================
echo.
echo APK Location:
echo build\app\outputs\flutter-apk\app-!FLAVOR!-release.apk
echo.
echo Built for: Android 13+ (arm64-v8a architecture only)
echo.
echo Both steps completed:
echo 1. App launcher icon changed
echo 2. Release APK built (arm64-v8a only)
echo.

pause
endlocal

@echo off
REM Debug script for Flutter flavors with full logging and debugging (Windows)
REM This script automatically:
REM   1. Prepares client assets
REM   2. Runs the app in debug mode with verbose logging
REM   3. Shows all logs including debug logs
REM   4. Enables hot reload and debugging
REM
REM Usage: debug.bat {flavor} [device] [--verbose]
REM Example: debug.bat afx
REM Example: debug.bat afx emulator-5554
REM Example: debug.bat afx --verbose

setlocal enabledelayedexpansion

REM Check arguments
if "%~1"=="" (
    echo Error: Missing flavor argument
    exit /b 1
)

set FLAVOR=%~1
set DEVICE=
set VERBOSE=false

REM Parse remaining arguments
shift
:parse_args
if "%~1"=="" goto end_parse
if /i "%~1"=="--verbose" (
    set VERBOSE=true
    shift
    goto parse_args
)
if /i "%~1"=="-v" (
    set VERBOSE=true
    shift
    goto parse_args
)
if "!DEVICE!"=="" (
    if not "%~1"=="" (
        set DEVICE=%~1
    )
)
shift
goto parse_args
:end_parse

echo [92m🐛 Debug Mode: %FLAVOR% flavor[0m
if not "!DEVICE!"=="" (
    echo [94m📱 Device: !DEVICE![0m
)
if "!VERBOSE!"=="true" (
    echo [94m📋 Verbose logging enabled[0m
)
echo.

REM Step 1: Prepare assets
echo [93m📦 Step 1: Preparing client assets...[0m
dart run scripts/prepare_flavor.dart %FLAVOR%
if errorlevel 1 (
    echo [91m❌ Failed to prepare assets[0m
    exit /b 1
)

REM Step 2: List available devices if no device specified
if "!DEVICE!"=="" (
    echo.
    echo [93m🔍 Available devices:[0m
    flutter devices
    echo.
    echo [94m💡 Tip: Specify a device ID to skip this step next time[0m
    echo [94m   Example: debug.bat %FLAVOR% emulator-5554[0m
    echo.
)

REM Step 3: Run in debug mode
echo.
echo [93m🐛 Step 2: Running app in DEBUG mode...[0m
echo [92m✅ All logs enabled (Trading, Chart, WebSocket, API, Order, Price, Debug)[0m
echo [92m✅ Hot reload enabled[0m
echo [92m✅ Debugger attached[0m
echo.

REM Build flutter run command
set FLUTTER_CMD=flutter run
set FLUTTER_CMD=!FLUTTER_CMD! --flavor %FLAVOR%
set FLUTTER_CMD=!FLUTTER_CMD! -t lib/main.dart
set FLUTTER_CMD=!FLUTTER_CMD! --dart-define=FLAVOR=%FLAVOR%
set FLUTTER_CMD=!FLUTTER_CMD! --debug

if not "!DEVICE!"=="" (
    set FLUTTER_CMD=!FLUTTER_CMD! -d !DEVICE!
)

if "!VERBOSE!"=="true" (
    set FLUTTER_CMD=!FLUTTER_CMD! --verbose
)

echo [94m🚀 Command: !FLUTTER_CMD![0m
echo.
echo [93m💡 Debug Tips:[0m
echo   • Press 'r' to hot reload
echo   • Press 'R' to hot restart
echo   • Press 'q' to quit
echo   • Press 'h' for help
echo   • Check logs below for detailed information
echo.
echo [92m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[0m
echo.

REM Execute the command
!FLUTTER_CMD!

endlocal


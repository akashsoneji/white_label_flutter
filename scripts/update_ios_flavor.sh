#!/bin/bash

# Script to update iOS app name and icon based on flavor
# Usage: bash scripts/update_ios_flavor.sh [flavor]
# Supported whitelabel flavors: tenax, vantage, celestial, pipze

MAIN_DART="lib/main.dart"
INFO_PLIST="ios/Runner/Info.plist"
PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"

if [ $# -ge 1 ] && [ -n "$1" ]; then
    FLAVOR="$1"
    echo "📱 Using provided flavor: $FLAVOR"
else
    FLAVOR=$(grep -E "^[[:space:]]*FlavorConfig\.(tenax|vantage|celestial|pipze)" "$MAIN_DART" | grep -v "^[[:space:]]*//" | head -1 | sed -E 's/.*FlavorConfig\.([a-z]+).*/\1/')

    if [ -z "$FLAVOR" ]; then
        FLAVOR=$(grep -E "String\.fromEnvironment\('FLAVOR'" "$MAIN_DART" | head -1 | sed -E "s/.*'FLAVOR', defaultValue: '([^']+)'.*/\1/")
    fi

    if [ -z "$FLAVOR" ]; then
        echo "⚠️  Could not detect flavor from $MAIN_DART"
        echo "   Provide flavor: bash scripts/update_ios_flavor.sh <tenax|vantage|celestial|pipze>"
        exit 1
    fi

    echo "📱 Detected flavor: $FLAVOR"
fi

case "$FLAVOR" in
    tenax)
        APP_NAME="Tenax"
        APP_ICON="tenax_app_icon"
        XCODE_CONFIG_PREFIX="Debug"
        ;;
    vantage)
        APP_NAME="Vantage"
        APP_ICON="AppIcon"
        XCODE_CONFIG_PREFIX="Debug-Vantage"
        ;;
    celestial)
        APP_NAME="Celestial"
        APP_ICON="AppIcon"
        XCODE_CONFIG_PREFIX="Debug-Celestial"
        ;;
    pipze)
        APP_NAME="Pipze"
        APP_ICON="AppIcon"
        XCODE_CONFIG_PREFIX="Debug-Pipze"
        ;;
    pippro)
        APP_NAME="PipPro"
        APP_ICON="AppIcon"
        XCODE_CONFIG_PREFIX="Debug-Pippro"
        ;;
    *)
        echo "❌ Unsupported flavor: $FLAVOR"
        echo "   Supported: tenax, vantage, celestial, pipze, pippro"
        exit 1
        ;;
esac

echo "📝 Updating app name to: $APP_NAME"
echo "🎨 Updating app icon to: $APP_ICON"
echo "⚙️  Xcode config family: $XCODE_CONFIG_PREFIX"

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$INFO_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$INFO_PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$INFO_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$INFO_PLIST"

if [ -f "$PROJECT_FILE" ]; then
    ICON_SET_PATH="ios/Runner/Assets.xcassets/${APP_ICON}.appiconset"
    if [ ! -d "$ICON_SET_PATH" ]; then
        echo "⚠️  Icon set not found: $ICON_SET_PATH — using AppIcon"
        APP_ICON="AppIcon"
    fi

    cp "$PROJECT_FILE" "${PROJECT_FILE}.bak"
    TEMP_FILE="${PROJECT_FILE}.tmp"
    sed "s/ASSETCATALOG_COMPILER_APPICON_NAME = [^;]*;/ASSETCATALOG_COMPILER_APPICON_NAME = $APP_ICON;/g" "$PROJECT_FILE" > "$TEMP_FILE"

    if [ $? -ne 0 ] || [ ! -f "$TEMP_FILE" ]; then
        echo "❌ Failed to update icon in project file"
        [ -f "${PROJECT_FILE}.bak" ] && mv "${PROJECT_FILE}.bak" "$PROJECT_FILE"
        rm -f "$TEMP_FILE"
        exit 1
    fi

    mv "$TEMP_FILE" "$PROJECT_FILE"
    echo "✅ Updated icon setting(s) to: $APP_ICON"
else
    echo "⚠️  Project file not found: $PROJECT_FILE"
fi

echo "✅ iOS flavor prep complete for: $FLAVOR ($APP_NAME)"
echo ""
echo "📋 Build with:"
echo "   flutter run --dart-define=CLIENT=$FLAVOR --dart-define=FLAVOR=$FLAVOR"
if [ "$FLAVOR" = "tenax" ] || [ "$FLAVOR" = "vantage" ] || [ "$FLAVOR" = "celestial" ] || [ "$FLAVOR" = "pipze" ]; then
    echo "   Android: add --flavor $FLAVOR"
fi
echo ""
echo "   iOS Xcode: select Debug-Celestial, Debug-Vantage, or Debug-Pipze configuration when building from Xcode"

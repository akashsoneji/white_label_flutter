#!/bin/bash

# Script to update iOS app name and icon based on FlavorConfig
# Usage: bash scripts/update_ios_flavor.sh [flavor]
#   If flavor is provided as argument, use it
#   Otherwise, read from main.dart

MAIN_DART="lib/main.dart"
INFO_PLIST="ios/Runner/Info.plist"
PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"

# Check if flavor is provided as argument
if [ $# -ge 1 ] && [ -n "$1" ]; then
    FLAVOR="$1"
    echo "📱 Using provided flavor: $FLAVOR"
else
    # Extract flavor from main.dart (ignore commented lines)
    FLAVOR=$(grep -E "^[[:space:]]*FlavorConfig\.(pipze|octa|fleza|tenax|onsa|profx|afx|vantage)" "$MAIN_DART" | grep -v "^[[:space:]]*//" | head -1 | sed -E 's/.*FlavorConfig\.([a-z]+).*/\1/')
    
    if [ -z "$FLAVOR" ]; then
        echo "⚠️  Could not detect flavor from $MAIN_DART"
        echo "   Make sure FlavorConfig.{flavor} is set in main.dart"
        echo "   Or provide flavor as argument: bash scripts/update_ios_flavor.sh <flavor>"
        exit 1
    fi
    
    echo "📱 Detected flavor from main.dart: $FLAVOR"
fi

# Map flavor to app name and icon (from flavor_config.dart)
case "$FLAVOR" in
    afx)
        APP_NAME="AFX"
        APP_ICON="AppIcon"  # Using default icon for now
        ;;
    pipze)
        APP_NAME="Pipze"
        APP_ICON="AppIcon"  # Using default icon for now
        ;;
    octa)
        APP_NAME="Octa"
        APP_ICON="AppIcon"  # Using default icon for now
        ;;
    fleza)
        APP_NAME="Fleza"
        APP_ICON="AppIcon"  # Using default icon for now
        ;;
    tenax)
        APP_NAME="Tenax"
        APP_ICON="tenax_app_icon"
        ;;
    onsa)
        APP_NAME="ONSA"
        APP_ICON="onsa_app_icon"
        ;;
    profx)
        APP_NAME="ProFX"
        APP_ICON="profx_app_icon"
        ;;
    vantage)
        APP_NAME="Vantage"
        APP_ICON="AppIcon"
        ;;
    *)
        APP_NAME="Pipze"
        APP_ICON="AppIcon"
        ;;
esac

echo "📝 Updating app name to: $APP_NAME"
echo "🎨 Updating app icon to: $APP_ICON"

# Update Info.plist using PlistBuddy
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$INFO_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$INFO_PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$INFO_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$INFO_PLIST"

# Update Xcode project file to change app icon
# This updates ASSETCATALOG_COMPILER_APPICON_NAME for Runner target (Debug, Release, Profile)
if [ -f "$PROJECT_FILE" ]; then
    # Check if icon set exists, if not use AppIcon as fallback
    ICON_SET_PATH="ios/Runner/Assets.xcassets/${APP_ICON}.appiconset"
    if [ ! -d "$ICON_SET_PATH" ]; then
        echo "⚠️  Icon set not found: $ICON_SET_PATH"
        echo "   Using default AppIcon. Please create $APP_ICON.appiconset in Assets.xcassets"
        echo "   Run: bash scripts/create_ios_icon_set.sh $FLAVOR <path_to_icon_image>"
        APP_ICON="AppIcon"
    fi
    
    # Create backup
    cp "$PROJECT_FILE" "${PROJECT_FILE}.bak"
    
    # Update ASSETCATALOG_COMPILER_APPICON_NAME for Runner target configurations only
    # We need to update lines that are in Runner target (97C147061CF9000F007C117D) sections
    # This includes Debug, Release configurations for Runner target
    
    # Use sed for reliable string replacement (works better in sandboxed environments)
    # Update ASSETCATALOG_COMPILER_APPICON_NAME in all Runner target configurations
    
    # Count occurrences before
    BEFORE_COUNT=$(grep -c "ASSETCATALOG_COMPILER_APPICON_NAME" "$PROJECT_FILE" 2>/dev/null || echo "0")
    
    # Use sed to replace all occurrences of ASSETCATALOG_COMPILER_APPICON_NAME
    # This will update Debug, Release, and Profile configurations
    # macOS sed requires -i '' for in-place editing, but we'll use a temp file approach for compatibility
    TEMP_FILE="${PROJECT_FILE}.tmp"
    sed "s/ASSETCATALOG_COMPILER_APPICON_NAME = [^;]*;/ASSETCATALOG_COMPILER_APPICON_NAME = $APP_ICON;/g" "$PROJECT_FILE" > "$TEMP_FILE"
    
    if [ $? -ne 0 ] || [ ! -f "$TEMP_FILE" ]; then
        echo "❌ Failed to update icon in project file"
        # Restore backup if update failed
        if [ -f "${PROJECT_FILE}.bak" ]; then
            mv "${PROJECT_FILE}.bak" "$PROJECT_FILE"
            echo "   Restored backup"
        fi
        rm -f "$TEMP_FILE"
        exit 1
    fi
    
    # Verify the update worked before replacing
    UPDATED_COUNT=$(grep -c "ASSETCATALOG_COMPILER_APPICON_NAME = $APP_ICON;" "$TEMP_FILE" 2>/dev/null || echo "0")
    
    if [ "$UPDATED_COUNT" -eq 0 ]; then
        echo "⚠️  Warning: Icon update may have failed. Verifying..."
        rm -f "$TEMP_FILE"
        # Restore backup if update failed
        if [ -f "${PROJECT_FILE}.bak" ]; then
            mv "${PROJECT_FILE}.bak" "$PROJECT_FILE"
        fi
        exit 1
    fi
    
    # Replace original file with updated version
    mv "$TEMP_FILE" "$PROJECT_FILE"
    
    echo "✅ Updated $UPDATED_COUNT icon setting(s) to: $APP_ICON"
    echo "   (Updated Debug, Release, and Profile configurations)"
else
    echo "⚠️  Project file not found: $PROJECT_FILE"
fi

echo "✅ iOS app name updated to: $APP_NAME"
echo "✅ iOS app icon updated to: $APP_ICON"
echo ""
echo "📋 Next steps:"
echo "   1. Clean Flutter build: flutter clean"
echo "   2. Delete app from simulator/device (if already installed)"
echo "   3. Rebuild and run: flutter run --dart-define=FLAVOR=$FLAVOR"
echo ""
echo "   Note: iOS caches app icons, so you may need to delete the app"
echo "   from the simulator/device before rebuilding to see the new icon."


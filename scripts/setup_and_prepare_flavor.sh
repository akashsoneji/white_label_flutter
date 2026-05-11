#!/bin/bash

# Script to detect flavor from main.dart, update icons/config for Android & iOS, and prepare for running
# This is called before running the app to ensure everything is set up correctly

MAIN_DART="lib/main.dart"

# Extract flavor from main.dart (ignore commented lines)
FLAVOR=$(grep -E "^[[:space:]]*FlavorConfig\.(pipze|octa|fleza|tenax|onsa|profx)" "$MAIN_DART" | grep -v "^[[:space:]]*//" | head -1 | sed -E 's/.*FlavorConfig\.([a-z]+).*/\1/')

if [ -z "$FLAVOR" ]; then
    echo "⚠️  Could not detect flavor from $MAIN_DART"
    echo "   Make sure FlavorConfig.{flavor} is set in main.dart"
    echo "   Defaulting to 'profx'"
    FLAVOR="profx"
fi

echo "🎨 Detected flavor from main.dart: $FLAVOR"
echo ""

# Update iOS configuration (pass the detected flavor)
echo "📱 Updating iOS configuration for flavor: $FLAVOR..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/update_ios_flavor.sh" "$FLAVOR" || {
    echo "⚠️  iOS update script not found or failed, continuing..."
}

# For Android, icons are already in flavor-specific directories
# The build system will automatically use the correct icons based on the flavor
echo "🤖 Android icons are in flavor-specific directories (will be used automatically)"
echo ""

# Get available devices
echo "🔍 Detecting available devices..."
DEVICES_OUTPUT=$(flutter devices 2>/dev/null)

# Parse devices
ANDROID_DEVICE=""
IOS_DEVICE=""

while IFS= read -r line; do
    if [[ "$line" =~ ^Found.*devices ]] || [[ "$line" =~ ^$ ]] || [[ "$line" =~ ^Checking ]] || [[ "$line" =~ ^Error: ]] || [[ "$line" =~ ^Run.*flutter ]]; then
        continue
    fi
    
    if [[ "$line" =~ \•[[:space:]]*([^[:space:]]+)[[:space:]]+\• ]]; then
        device_id="${BASH_REMATCH[1]}"
        if [[ "$device_id" == emulator-* ]] || [[ "$line" == *android* ]] || [[ "$line" == *Android* ]]; then
            ANDROID_DEVICE="$device_id"
        fi
        if [[ "$line" == *iPhone* ]] || [[ "$line" == *iPad* ]] || [[ "$line" == *ios* ]] || [[ "$line" == *simulator* ]]; then
            IOS_DEVICE="$device_id"
        fi
    fi
done <<< "$DEVICES_OUTPUT"

# Determine which device to use
SELECTED_DEVICE=""
IS_IOS=false

if [ -n "$ANDROID_DEVICE" ]; then
    SELECTED_DEVICE="$ANDROID_DEVICE"
    echo "📱 Found Android device: $SELECTED_DEVICE"
elif [ -n "$IOS_DEVICE" ]; then
    SELECTED_DEVICE="$IOS_DEVICE"
    IS_IOS=true
    echo "📱 Found iOS device: $SELECTED_DEVICE"
else
    echo "⚠️  No devices found. Please start an emulator or connect a device."
    SELECTED_DEVICE="emulator-5554"  # Default fallback
    echo "   Will try to use default device: $SELECTED_DEVICE"
fi

# Write to files for the run script to use
mkdir -p /tmp
echo "$FLAVOR" > /tmp/vscode_flutter_flavor.txt
echo "$SELECTED_DEVICE" > /tmp/vscode_flutter_device.txt
echo "$IS_IOS" > /tmp/vscode_flutter_is_ios.txt

# Also write to workspace for launch configuration to read
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
mkdir -p "${WORKSPACE_DIR}/.vscode"
echo "$FLAVOR" > "${WORKSPACE_DIR}/.vscode/.detected_flavor.txt" 2>/dev/null

# Export as environment variable for launch configuration
export DETECTED_FLAVOR="$FLAVOR"
echo "DETECTED_FLAVOR=$FLAVOR" >> "${WORKSPACE_DIR}/.vscode/.env" 2>/dev/null || true

# Output the flavor so it can be used
echo "FLAVOR=$FLAVOR"

echo ""
echo "✅ Setup complete!"
echo "   Flavor: $FLAVOR"
echo "   Device: $SELECTED_DEVICE"
echo "   Platform: $([ "$IS_IOS" = "true" ] && echo "iOS" || echo "Android")"
echo ""
echo "💡 IMPORTANT: When prompted for flavor below, type: $FLAVOR (or press Enter if default matches)"
echo ""


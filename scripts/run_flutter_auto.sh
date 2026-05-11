#!/bin/bash

# Script to automatically run Flutter with flavor detected from main.dart
# This is used by VS Code launch configuration

MAIN_DART="lib/main.dart"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# Update iOS configuration (will be updated again with correct flavor when device is selected)
# This is removed to avoid double update - we'll update with the correct flavor later

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

# Determine which device to use (prefer Android if both available)
SELECTED_DEVICE=""
IS_IOS=false

if [ -n "$ANDROID_DEVICE" ]; then
    SELECTED_DEVICE="$ANDROID_DEVICE"
    echo "📱 Using Android device: $SELECTED_DEVICE"
elif [ -n "$IOS_DEVICE" ]; then
    SELECTED_DEVICE="$IOS_DEVICE"
    IS_IOS=true
    echo "📱 Using iOS device: $SELECTED_DEVICE"
else
    echo "❌ No devices found. Please start an emulator or connect a device."
    exit 1
fi

echo ""
echo "✅ Ready to run!"
echo "   Flavor: $FLAVOR"
echo "   Device: $SELECTED_DEVICE"
echo "   Platform: $([ "$IS_IOS" = "true" ] && echo "iOS" || echo "Android")"
echo ""

# Run Flutter with appropriate flags
# iOS uses --dart-define, Android uses --flavor
if [ "$IS_IOS" = "true" ]; then
    echo "🚀 Running on iOS with flavor: $FLAVOR..."
    echo "   Using --dart-define=FLAVOR instead of --flavor for iOS"
    # Update iOS config first
    bash "$SCRIPT_DIR/update_ios_flavor.sh" "$FLAVOR" 2>/dev/null || true
    # Use --dart-define for iOS instead of --flavor
    flutter run --dart-define=FLAVOR="$FLAVOR" -d "$SELECTED_DEVICE"
else
    echo "🚀 Running on Android with flavor: $FLAVOR..."
    flutter run --flavor "$FLAVOR" -d "$SELECTED_DEVICE"
fi


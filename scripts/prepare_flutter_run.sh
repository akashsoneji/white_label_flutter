#!/bin/bash

# Prepare script for VS Code launch configuration
# Detects flavor and device, writes them to files for VS Code to use

MAIN_DART="lib/main.dart"

# Extract flavor from main.dart (ignore commented lines)
FLAVOR=$(grep -E "^[[:space:]]*FlavorConfig\.(pipze|octa|fleza|tenax|onsa)" "$MAIN_DART" | grep -v "^[[:space:]]*//" | head -1 | sed -E 's/.*FlavorConfig\.([a-z]+).*/\1/')

if [ -z "$FLAVOR" ]; then
    echo "⚠️  Could not detect flavor from $MAIN_DART"
    echo "   Make sure FlavorConfig.{flavor} is set in main.dart"
    exit 1
fi

echo "🎨 Detected flavor: $FLAVOR"

# Get available devices
DEVICES_OUTPUT=$(flutter devices 2>/dev/null)

# Parse devices - format: "  device_name • device_id • platform • other_info"
ANDROID_DEVICE=""
IOS_DEVICE=""

# Check for Android devices (emulator- or android in device_id or platform)
while IFS= read -r line; do
    # Skip header lines and empty lines
    if [[ "$line" =~ ^Found.*devices ]] || [[ "$line" =~ ^$ ]] || [[ "$line" =~ ^Checking ]] || [[ "$line" =~ ^Error: ]] || [[ "$line" =~ ^Run.*flutter ]]; then
        continue
    fi
    
    # Extract device ID (second field after •)
    if [[ "$line" =~ \•[[:space:]]*([^[:space:]]+)[[:space:]]+\• ]]; then
        device_id="${BASH_REMATCH[1]}"
        # Check if it's Android
        if [[ "$device_id" == emulator-* ]] || [[ "$line" == *android* ]] || [[ "$line" == *Android* ]]; then
            ANDROID_DEVICE="$device_id"
            break
        fi
        # Check if it's iOS
        if [[ "$line" == *iPhone* ]] || [[ "$line" == *iPad* ]] || [[ "$line" == *ios* ]] || [[ "$device_id" =~ ^[A-F0-9-]{36}$ ]]; then
            # iOS simulators have UUID device IDs
            if [[ "$line" == *iPhone* ]] || [[ "$line" == *iPad* ]] || [[ "$line" == *ios* ]] || [[ "$line" == *simulator* ]]; then
                IOS_DEVICE="$device_id"
                break
            fi
        fi
    fi
done <<< "$DEVICES_OUTPUT"

# If still not found, try simpler parsing
if [ -z "$ANDROID_DEVICE" ]; then
    ANDROID_DEVICE=$(echo "$DEVICES_OUTPUT" | grep -E "emulator-|android" | head -1 | awk -F' • ' '{print $2}' | xargs)
fi

if [ -z "$IOS_DEVICE" ]; then
    # iOS device ID is the UUID (second field)
    IOS_DEVICE=$(echo "$DEVICES_OUTPUT" | grep -E "iPhone|iPad|ios|simulator" | head -1 | awk -F' • ' '{print $2}' | xargs)
fi

# Determine which device to use (use whichever is available)
SELECTED_DEVICE=""
IS_IOS=false

if [ -n "$ANDROID_DEVICE" ] && [ "$ANDROID_DEVICE" != "emulator-5554" ]; then
    # Only use Android if we actually found a running device
    SELECTED_DEVICE="$ANDROID_DEVICE"
    echo "📱 Found Android device: $SELECTED_DEVICE"
elif [ -n "$IOS_DEVICE" ]; then
    SELECTED_DEVICE="$IOS_DEVICE"
    IS_IOS=true
    echo "📱 Found iOS device: $SELECTED_DEVICE"
    # Update iOS flavor config (pass the detected flavor)
    echo "🍎 Updating iOS flavor configuration for flavor: $FLAVOR..."
    bash scripts/update_ios_flavor.sh "$FLAVOR"
    if [ $? -ne 0 ]; then
        echo "❌ Failed to update iOS flavor configuration"
        exit 1
    fi
elif [ -n "$ANDROID_DEVICE" ]; then
    # Fallback to Android even if it's the default
    SELECTED_DEVICE="$ANDROID_DEVICE"
    echo "📱 Using Android device: $SELECTED_DEVICE"
else
    echo "❌ No devices found. Please start an emulator or connect a device."
    exit 1
fi

echo "✅ Using device: $SELECTED_DEVICE ($([ "$IS_IOS" = "true" ] && echo "iOS" || echo "Android"))"

# Write to files for VS Code to use
echo "$FLAVOR" > /tmp/vscode_flutter_flavor.txt
echo "$SELECTED_DEVICE" > /tmp/vscode_flutter_device.txt
echo "$IS_IOS" > /tmp/vscode_flutter_is_ios.txt

# Write args format for VS Code (iOS doesn't need --flavor flag)
if [ "$IS_IOS" = "true" ]; then
    # iOS: just device, no flavor
    echo "-d" > /tmp/vscode_flutter_args.txt
    echo "$SELECTED_DEVICE" >> /tmp/vscode_flutter_args.txt
else
    # Android: flavor and device
    echo "--flavor" > /tmp/vscode_flutter_args.txt
    echo "$FLAVOR" >> /tmp/vscode_flutter_args.txt
    echo "-d" >> /tmp/vscode_flutter_args.txt
    echo "$SELECTED_DEVICE" >> /tmp/vscode_flutter_args.txt
fi

# Also write to a format that VS Code can read easily
echo "FLAVOR=$FLAVOR" > /tmp/vscode_flutter_env.txt
echo "DEVICE=$SELECTED_DEVICE" >> /tmp/vscode_flutter_env.txt
echo "IS_IOS=$IS_IOS" >> /tmp/vscode_flutter_env.txt

echo "✅ Prepared: flavor=$FLAVOR, device=$SELECTED_DEVICE, is_ios=$IS_IOS"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📝 COPY THESE VALUES WHEN PROMPTED BY VS CODE:"
echo "═══════════════════════════════════════════════════════════════"
echo "   Flavor: $FLAVOR"
echo "   Device: $SELECTED_DEVICE"
echo "   Platform: $([ "$IS_IOS" = "true" ] && echo "iOS" || echo "Android")"
echo "═══════════════════════════════════════════════════════════════"
echo ""
if [ "$IS_IOS" = "true" ]; then
    echo "⚠️  NOTE: For iOS, you can ignore the --flavor prompt"
    echo "   Just enter the Device ID: $SELECTED_DEVICE"
    echo ""
fi


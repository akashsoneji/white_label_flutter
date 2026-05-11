#!/bin/bash

# Wrapper script that reads prepared values and runs Flutter
# This is called by VS Code launch configuration after prepare-flutter-run task

FLAVOR_FILE="/tmp/vscode_flutter_flavor.txt"
DEVICE_FILE="/tmp/vscode_flutter_device.txt"
IS_IOS_FILE="/tmp/vscode_flutter_is_ios.txt"

# Read values from files
FLAVOR=$(cat "$FLAVOR_FILE" 2>/dev/null | tr -d '\n' || echo "tenax")
DEVICE=$(cat "$DEVICE_FILE" 2>/dev/null | tr -d '\n' || echo "emulator-5554")
IS_IOS=$(cat "$IS_IOS_FILE" 2>/dev/null | tr -d '\n' || echo "false")

echo "🎨 Using flavor: $FLAVOR"
echo "📱 Using device: $DEVICE"
echo "🍎 Is iOS: $IS_IOS"
echo ""

# Step 1: Prepare assets
echo "📦 Preparing client assets for $FLAVOR..."
dart run scripts/prepare_flavor.dart "$FLAVOR" || {
    echo "❌ Failed to prepare assets"
    exit 1
}
echo ""

# Build and run flutter command
if [ "$IS_IOS" = "true" ]; then
    # iOS: Update flavor config first, then use --dart-define instead of --flavor
    # Flutter iOS doesn't support --flavor when only default Runner scheme exists
    echo "📱 Updating iOS configuration for flavor: $FLAVOR..."
    bash scripts/update_ios_flavor.sh "$FLAVOR"
    if [ $? -ne 0 ]; then
        echo "❌ Failed to update iOS flavor configuration"
        exit 1
    fi
    echo "🚀 Running on iOS simulator with flavor: $FLAVOR..."
    echo "   Note: Using --dart-define=FLAVOR instead of --flavor for iOS"
    # Use --dart-define to pass flavor to Flutter (main.dart reads it from environment)
    flutter run --dart-define=FLAVOR="$FLAVOR" -d "$DEVICE"
else
    # Android needs --flavor flag
    echo "🚀 Running on Android emulator with flavor: $FLAVOR..."
    flutter run --flavor "$FLAVOR" -d "$DEVICE"
fi


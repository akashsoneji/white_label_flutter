#!/bin/bash

# Script to prepare and configure iOS build for a specific flavor/client
# Usage: ./prepare_ios.sh [tenax|vantage|celestial|pipze|proactive]

if [ $# -lt 1 ]; then
    echo "❌ Error: Please specify a flavor"
    echo "Usage: ./prepare_ios.sh [tenax|vantage|celestial|pipze|proactive]"
    exit 1
fi

FLAVOR=$(echo "$1" | tr '[:upper:]' '[:lower:]')

case "$FLAVOR" in
    tenax|vantage|celestial|pipze|proactive)
        ;;
    *)
        echo "❌ Error: Unsupported flavor: $FLAVOR"
        echo "Supported: tenax, vantage, celestial, pipze, proactive"
        exit 1
        ;;
esac

echo "🚀 Preparing iOS environment for flavor: $FLAVOR..."

# 1. Run the dart flavor preparer (copies assets, generates launcher icons, updates pubspec)
echo "📦 Running prepare_flavor.dart..."
dart run scripts/prepare_flavor.dart "$FLAVOR"
if [ $? -ne 0 ]; then
    echo "❌ Error: Dart flavor preparation failed"
    exit 1
fi

# 2. Update iOS specific configurations (app name, icon reference in pbxproj)
echo "📱 Updating iOS app configuration..."
bash scripts/update_ios_flavor.sh "$FLAVOR"
if [ $? -ne 0 ]; then
    echo "❌ Error: iOS flavor update failed"
    exit 1
fi

echo "✅ iOS environment successfully prepared for: $FLAVOR"
echo ""
echo "💡 IMPORTANT: Since the iOS project uses a single target scheme, DO NOT use the --flavor option on iOS."
echo "   Run the app with:"
echo "   flutter run --dart-define=CLIENT=$FLAVOR --dart-define=FLAVOR=$FLAVOR"
echo ""
echo "   Build the release app with:"
echo "   flutter build ipa --dart-define=CLIENT=$FLAVOR --dart-define=FLAVOR=$FLAVOR"
echo ""

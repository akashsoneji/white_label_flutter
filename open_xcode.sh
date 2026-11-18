#!/bin/bash

# Prepare a flavor for iOS and open it directly in Xcode.
# Usage: ./open_xcode.sh [tenax|vantage|celestial|pipze|proactive]   (default: proactive)

set -e

FLAVOR=$(echo "${1:-proactive}" | tr '[:upper:]' '[:lower:]')
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# dart/flutter and the user-level CocoaPods gem are not on PATH by default.
export PATH="$HOME/development/flutter/bin:$HOME/.gem/ruby/2.6.0/bin:$PATH"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

cd "$PROJECT_DIR"

bash prepare_ios.sh "$FLAVOR"

echo "📦 Running flutter pub get..."
flutter pub get

# Pods/ and Runner.xcworkspace are gitignored, so they must be generated before Xcode can open the workspace.
echo "📦 Running pod install..."
(cd ios && pod install)

echo "🛠  Opening Xcode for: $FLAVOR"
open ios/Runner.xcworkspace

echo ""
echo "✅ Xcode is open. Pick 'Runner' + your iPhone at the top, then press ⌘R."

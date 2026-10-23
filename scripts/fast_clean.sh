#!/usr/bin/env bash
# Fast clean for the VS Code prepare-<brand> tasks.
#
# Deletes the same build artifacts as `flutter clean`, but skips its slow first
# step: `xcodebuild clean` on ios/Runner.xcworkspace (~28s plus a Swift PM
# fetch), which an Android run never needs.
#
# Usage: bash scripts/fast_clean.sh          # Android run (default)
#        bash scripts/fast_clean.sh --ios    # full `flutter clean` incl. Xcode
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--ios" ]]; then
  exec flutter clean
fi

rm -rf \
  build \
  .dart_tool \
  .flutter-plugins-dependencies \
  ios/Flutter/ephemeral \
  ios/Flutter/Generated.xcconfig \
  ios/Flutter/flutter_export_environment.sh \
  ios/Flutter/Flutter.podspec \
  macos/Flutter/ephemeral \
  linux/flutter/ephemeral \
  windows/flutter/ephemeral

echo "Fast clean done (Xcode workspace clean skipped; use --ios for a full flutter clean)."

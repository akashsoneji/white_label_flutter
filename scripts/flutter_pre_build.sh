#!/bin/bash

# Pre-build script for Flutter iOS
# Updates iOS app name and icon based on FlavorConfig in main.dart
# This script runs automatically before Flutter builds iOS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# Try to detect flavor from main.dart or environment variable
MAIN_DART="lib/main.dart"
FLAVOR=""

# First, try to get flavor from environment variable (set by Flutter build)
if [ -n "$FLAVOR" ]; then
    FLAVOR="$FLAVOR"
elif [ -n "$DART_DEFINE_FLAVOR" ]; then
    FLAVOR="$DART_DEFINE_FLAVOR"
else
    # Fallback: extract from main.dart
    FLAVOR=$(grep -E "^[[:space:]]*FlavorConfig\.(pipze|octa|fleza|tenax|onsa|profx|afx)" "$MAIN_DART" 2>/dev/null | grep -v "^[[:space:]]*//" | head -1 | sed -E 's/.*FlavorConfig\.([a-z]+).*/\1/' || echo "")
fi

# Run the flavor update script (with flavor if detected, otherwise let it detect from main.dart)
if [ -n "$FLAVOR" ]; then
    bash "$SCRIPT_DIR/update_ios_flavor.sh" "$FLAVOR"
else
    bash "$SCRIPT_DIR/update_ios_flavor.sh"
fi


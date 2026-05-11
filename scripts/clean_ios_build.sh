#!/bin/bash

# Script to completely clean iOS build and caches
# This helps ensure app icons update correctly

set -e

echo "🧹 Cleaning iOS build and caches..."
echo ""

# 1. Clean Flutter build
echo "📦 Step 1: Cleaning Flutter build..."
flutter clean
echo "✅ Flutter clean completed"
echo ""

# 2. Clean Xcode derived data
echo "📦 Step 2: Cleaning Xcode derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
echo "✅ Xcode derived data cleaned"
echo ""

# 3. Clean iOS build folder
echo "📦 Step 3: Cleaning iOS build folder..."
rm -rf ios/build
rm -rf ios/Pods
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
echo "✅ iOS build folder cleaned"
echo ""

# 4. Clean Pods
echo "📦 Step 4: Reinstalling Pods..."
cd ios
pod deintegrate 2>/dev/null || true
pod install
cd ..
echo "✅ Pods reinstalled"
echo ""

# 5. Get pub packages
echo "📦 Step 5: Getting Flutter packages..."
flutter pub get
echo "✅ Flutter packages updated"
echo ""

echo "✅ All cleanup completed!"
echo ""
echo "📋 Next steps:"
echo "   1. Delete the app from simulator/device (long press and delete)"
echo "   2. Run: flutter run --dart-define=FLAVOR=<your-flavor> -d <device>"
echo "   3. Or use: bash scripts/run_ios_flavor.sh <flavor>"
echo ""
echo "   Note: Make sure you've run: bash scripts/update_ios_flavor.sh <flavor>"
echo "   before rebuilding to set the correct icon."


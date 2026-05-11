#!/bin/bash

# Build script for Flutter flavors with centralized asset management
# This script automatically:
#   1. Increments version code (for release builds) - allows users to update without uninstalling
#   2. Copies client assets from lib/clients/{flavor}/assets/
#   3. Generates native splash screens with client colors
#   4. Generates launcher icons from client assets
#   5. Builds the app using centralized main.dart with auto flavor detection
#   6. Builds APK/AAB for all Android devices (supports all architectures)
#
# Usage: 
#   Single client: ./build.sh {flavor} {build_type} [mode]
#   All clients:   ./build.sh all {build_type} [mode]
# Example: 
#   ./build.sh afx apk release
#   ./build.sh all apk release

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to increment full version in pubspec.yaml
# Format: version: X.Y.Z+BUILD_NUMBER
# - Bumps patch part of X.Y.Z -> X.Y.(Z+1)
# - Bumps BUILD_NUMBER -> (BUILD_NUMBER+1)
increment_version_code() {
    local PUBSPEC_FILE="pubspec.yaml"
    
    if [ ! -f "$PUBSPEC_FILE" ]; then
        echo -e "${YELLOW}⚠️  Warning: pubspec.yaml not found, skipping version increment${NC}"
        return 0
    fi
    
    # Read current version
    local CURRENT_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | tr -d ' ')
    
    if [ -z "$CURRENT_VERSION" ]; then
        echo -e "${YELLOW}⚠️  Warning: Could not find version in pubspec.yaml${NC}"
        return 0
    fi
    
    # Extract version name and build number
    local VERSION_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
    local BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

    # Parse semantic version parts
    local MAJOR=0
    local MINOR=0
    local PATCH=0
    IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION_NAME"

    if [ -z "$MAJOR" ]; then MAJOR=0; fi
    if [ -z "$MINOR" ]; then MINOR=0; fi
    if [ -z "$PATCH" ]; then PATCH=0; fi

    # If no build number exists, start at 1
    if [ -z "$BUILD_NUMBER" ] || [ "$BUILD_NUMBER" == "$CURRENT_VERSION" ]; then
        BUILD_NUMBER=1
    else
        # Increment build number
        BUILD_NUMBER=$((BUILD_NUMBER + 1))
    fi

    # Increment patch part for "full" version bump
    PATCH=$((PATCH + 1))

    local NEW_VERSION_NAME="${MAJOR}.${MINOR}.${PATCH}"
    local NEW_VERSION="${NEW_VERSION_NAME}+${BUILD_NUMBER}"
    
    # Update pubspec.yaml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version:.*/version: $NEW_VERSION/" "$PUBSPEC_FILE"
    else
        # Linux
        sed -i "s/^version:.*/version: $NEW_VERSION/" "$PUBSPEC_FILE"
    fi
    
    echo -e "${GREEN}📈 Version updated: $CURRENT_VERSION → $NEW_VERSION${NC}"
    return 0
}

# Function to build a single flavor
build_flavor() {
    local FLAVOR=$1
    local BUILD_TYPE=$2
    local MODE=$3
    local SKIP_VERSION_INCREMENT=${4:-false}
    local UNIVERSAL_APK=${5:-false}
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🚀 Building $FLAVOR flavor ($BUILD_TYPE, $MODE mode)${NC}"
    if [ "$BUILD_TYPE" == "apk" ] && [ "$UNIVERSAL_APK" == "true" ]; then
        echo -e "${BLUE}📱 Target: Universal APK (single APK, all architectures)${NC}"
    else
        echo -e "${BLUE}📱 Target: All Android devices (all architectures)${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Step 0: Increment version code for release builds (so users can update without uninstalling)
    # Skip if building multiple clients (version already incremented)
    if [ "$MODE" == "release" ] && [ "$SKIP_VERSION_INCREMENT" != "true" ]; then
        echo -e "${YELLOW}📈 Step 0: Incrementing full version...${NC}"
        increment_version_code
        echo ""
    fi
    
    # Step 1: Prepare assets
    echo -e "${YELLOW}📦 Step 1: Preparing client assets for $FLAVOR...${NC}"
    if ! dart run scripts/prepare_flavor.dart $FLAVOR; then
        echo -e "${RED}❌ Failed to prepare assets for $FLAVOR${NC}"
        return 1
    fi
    
    # Step 2: Build
    if [ "$BUILD_TYPE" == "apk" ] && [ "$UNIVERSAL_APK" == "true" ]; then
        echo -e "\n${YELLOW}🔨 Step 2: Building Flutter app for $FLAVOR (universal APK, single file)...${NC}"
    else
        echo -e "\n${YELLOW}🔨 Step 2: Building Flutter app for $FLAVOR (all architectures with split APKs)...${NC}"
    fi
    local BUILD_CMD=""
    local SPLIT_FLAG=""
    if [ "$BUILD_TYPE" == "apk" ] && [ "$UNIVERSAL_APK" != "true" ]; then
        SPLIT_FLAG=" --split-per-abi"
    fi
    if [ "$MODE" == "release" ]; then
        if [ "$BUILD_TYPE" == "apk" ]; then
            BUILD_CMD="flutter build $BUILD_TYPE --flavor $FLAVOR --dart-define=FLAVOR=$FLAVOR --release$SPLIT_FLAG"
        else
            BUILD_CMD="flutter build $BUILD_TYPE --flavor $FLAVOR --dart-define=FLAVOR=$FLAVOR --release"
        fi
    elif [ "$MODE" == "debug" ]; then
        if [ "$BUILD_TYPE" == "apk" ]; then
            BUILD_CMD="flutter build $BUILD_TYPE --flavor $FLAVOR --dart-define=FLAVOR=$FLAVOR --debug$SPLIT_FLAG"
        else
            BUILD_CMD="flutter build $BUILD_TYPE --flavor $FLAVOR --dart-define=FLAVOR=$FLAVOR --debug"
        fi
    elif [ "$MODE" == "profile" ]; then
        if [ "$BUILD_TYPE" == "apk" ]; then
            BUILD_CMD="flutter build $BUILD_TYPE --flavor $FLAVOR --dart-define=FLAVOR=$FLAVOR --profile$SPLIT_FLAG"
        else
            BUILD_CMD="flutter build $BUILD_TYPE --flavor $FLAVOR --dart-define=FLAVOR=$FLAVOR --profile"
        fi
    else
        echo -e "${RED}❌ Invalid mode: $MODE${NC}"
        return 1
    fi
    
    if ! $BUILD_CMD; then
        echo -e "${RED}❌ Build failed for $FLAVOR${NC}"
        return 1
    fi
    
    # Step 3: Rename + show output location (include version name in file names)
    echo -e "\n${GREEN}✅ Build completed successfully for $FLAVOR!${NC}"
    if [ "$BUILD_TYPE" == "apk" ]; then
        local PUBSPEC_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
        local VERSION_NAME=$(echo "$PUBSPEC_VERSION" | cut -d'+' -f1)
        local APK_OUTPUT_DIR="build/app/outputs/flutter-apk"
        local OUTPUT_PREFIX="${FLAVOR^^}_V${VERSION_NAME}"

        # Universal APK: single file app-{flavor}-{mode}.apk
        UNIVERSAL_APK_PATH="${APK_OUTPUT_DIR}/app-$FLAVOR-$MODE.apk"
        UNIVERSAL_APK_PATH_NEW="${APK_OUTPUT_DIR}/${OUTPUT_PREFIX}_${MODE}.apk"

        if [ "$UNIVERSAL_APK" == "true" ]; then
            if [ -f "$UNIVERSAL_APK_PATH" ]; then
                mv "$UNIVERSAL_APK_PATH" "$UNIVERSAL_APK_PATH_NEW" 2>/dev/null || true
                UNIVERSAL_APK_PATH="$UNIVERSAL_APK_PATH_NEW"
                APK_SIZE=$(du -h "$UNIVERSAL_APK_PATH" | cut -f1)
                echo -e "${GREEN}📱 Universal APK: $UNIVERSAL_APK_PATH ($APK_SIZE)${NC}"
            else
                echo -e "${YELLOW}⚠️  Universal APK not found at $UNIVERSAL_APK_PATH${NC}"
                find build/app/outputs/flutter-apk -name "*$FLAVOR*.apk" 2>/dev/null | head -5
            fi
        else
            # With --split-per-abi, Flutter creates separate APKs for each architecture
            echo -e "${GREEN}📱 Split APKs created (one per architecture):${NC}"
            APK_FOUND=false
            for ABI in arm64-v8a armeabi-v7a x86_64; do
                # Flutter output naming when using --split-per-abi:
                # app-<abi>-<flavor>-<mode>.apk
                APK_PATH="${APK_OUTPUT_DIR}/app-$ABI-$FLAVOR-$MODE.apk"
                APK_PATH_NEW="${APK_OUTPUT_DIR}/${OUTPUT_PREFIX}_${MODE}_${ABI}.apk"
                if [ -f "$APK_PATH" ]; then
                    mv "$APK_PATH" "$APK_PATH_NEW" 2>/dev/null || true
                    APK_PATH="$APK_PATH_NEW"
                    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
                    echo -e "${GREEN}  ✓ $ABI: $APK_PATH ($APK_SIZE)${NC}"
                    APK_FOUND=true
                fi
            done
            if [ -f "$UNIVERSAL_APK_PATH" ]; then
                mv "$UNIVERSAL_APK_PATH" "$UNIVERSAL_APK_PATH_NEW" 2>/dev/null || true
                UNIVERSAL_APK_PATH="$UNIVERSAL_APK_PATH_NEW"
                APK_SIZE=$(du -h "$UNIVERSAL_APK_PATH" | cut -f1)
                echo -e "${GREEN}  ✓ Universal: $UNIVERSAL_APK_PATH ($APK_SIZE)${NC}"
                APK_FOUND=true
            fi
            if [ "$APK_FOUND" == false ]; then
                echo -e "${YELLOW}⚠️  APK not found at expected paths${NC}"
                find build/app/outputs/flutter-apk -name "*$FLAVOR*.apk" 2>/dev/null | head -5
            fi
        fi
    elif [ "$BUILD_TYPE" == "appbundle" ]; then
        AAB_PATH="build/app/outputs/bundle/${FLAVOR}Release/app-$FLAVOR-release.aab"
        if [ -f "$AAB_PATH" ]; then
            AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
            echo -e "${GREEN}📦 AAB location: $AAB_PATH${NC}"
            echo -e "${GREEN}📦 AAB size: $AAB_SIZE${NC}"
        else
            echo -e "${GREEN}📦 AAB location: $AAB_PATH${NC}"
        fi
    fi
    if [ "$BUILD_TYPE" == "apk" ]; then
        if [ "$UNIVERSAL_APK" == "true" ]; then
            echo -e "${BLUE}ℹ️  Built universal APK (single file for all architectures)${NC}"
        else
            echo -e "${BLUE}ℹ️  Built split APKs for all Android devices (separate APK per architecture)${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  Built for all Android devices (all architectures supported)${NC}"
    fi
    
    return 0
}

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}❌ Error: Missing arguments${NC}"
    echo ""
    echo "Usage:"
    echo "  Single client: ./build.sh {flavor} {build_type} [mode] [universal]"
    echo "  All clients:   ./build.sh all {build_type} [mode] [universal]"
    echo ""
    echo "Arguments:"
    echo "  flavor: afx, kantara, pipze, onsa, tenax, profx, tradoxy, askbid, sr, vr19, or 'all'"
    echo "  build_type: apk, appbundle"
    echo "  mode: release (default), debug, profile"
    echo "  universal: (optional) use 'universal' to build a single APK for all architectures (no split)"
    echo ""
    echo "Examples:"
    echo "  ./build.sh afx apk release           # Split APKs (one per ABI)"
    echo "  ./build.sh tenax apk release universal   # Single universal release APK"
    echo "  ./build.sh all apk release"
    echo "  ./build.sh pipze appbundle release"
    echo ""
    echo -e "${BLUE}ℹ️  Default APK: split per ABI. Add 'universal' for one APK for all devices.${NC}"
    exit 1
fi

FLAVOR=$1
BUILD_TYPE=$2
MODE=${3:-release}
BUILD_UNIVERSAL_APK="false"
if [ -n "$4" ] && [ "$4" == "universal" ]; then
    BUILD_UNIVERSAL_APK="true"
fi

# Validate build type
if [ "$BUILD_TYPE" != "apk" ] && [ "$BUILD_TYPE" != "appbundle" ]; then
    echo -e "${RED}❌ Invalid build_type: $BUILD_TYPE${NC}"
    echo "  build_type must be: apk or appbundle"
    exit 1
fi

# Validate mode
if [ "$MODE" != "release" ] && [ "$MODE" != "debug" ] && [ "$MODE" != "profile" ]; then
    echo -e "${RED}❌ Invalid mode: $MODE${NC}"
    echo "  mode must be: release, debug, or profile"
    exit 1
fi

# Build all clients if "all" is specified
if [ "$FLAVOR" == "all" ]; then
    # Define all clients to build
    CLIENTS=("tradoxy" "tenax" "afx" "kantara" "onsa" "pipze" "askbid" "profx" "sr" "vr19")
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🚀 Building ALL clients: ${CLIENTS[*]}${NC}"
    echo -e "${BLUE}📱 Build type: $BUILD_TYPE | Mode: $MODE${NC}"
    echo -e "${BLUE}📱 Target: All Android devices (all architectures)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Increment version code once for all builds (only for release mode)
    if [ "$MODE" == "release" ]; then
        echo -e "${YELLOW}📈 Incrementing full version for all builds...${NC}"
        increment_version_code
        echo ""
    fi

    PUBSPEC_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
    VERSION_NAME=$(echo "$PUBSPEC_VERSION" | cut -d'+' -f1)
    APK_OUTPUT_DIR="build/app/outputs/flutter-apk"
    
    # Track results
    SUCCESSFUL=()
    FAILED=()
    START_TIME=$(date +%s)
    
    # Build each client (skip version increment since we did it once above)
    for CLIENT in "${CLIENTS[@]}"; do
        CLIENT_START=$(date +%s)
        if build_flavor "$CLIENT" "$BUILD_TYPE" "$MODE" "true" "$BUILD_UNIVERSAL_APK"; then
            SUCCESSFUL+=("$CLIENT")
            CLIENT_END=$(date +%s)
            CLIENT_DURATION=$((CLIENT_END - CLIENT_START))
            echo -e "${GREEN}✅ $CLIENT completed in ${CLIENT_DURATION}s${NC}"
        else
            FAILED+=("$CLIENT")
            CLIENT_END=$(date +%s)
            CLIENT_DURATION=$((CLIENT_END - CLIENT_START))
            echo -e "${RED}❌ $CLIENT failed after ${CLIENT_DURATION}s${NC}"
        fi
    done
    
    # Summary
    END_TIME=$(date +%s)
    TOTAL_DURATION=$((END_TIME - START_TIME))
    TOTAL_MINUTES=$((TOTAL_DURATION / 60))
    TOTAL_SECONDS=$((TOTAL_DURATION % 60))
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📊 BUILD SUMMARY${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Successful builds: ${#SUCCESSFUL[@]}/${#CLIENTS[@]}${NC}"
    if [ ${#SUCCESSFUL[@]} -gt 0 ]; then
        echo -e "${GREEN}   Clients: ${SUCCESSFUL[*]}${NC}"
    fi
    
    if [ ${#FAILED[@]} -gt 0 ]; then
        echo -e "${RED}❌ Failed builds: ${#FAILED[@]}/${#CLIENTS[@]}${NC}"
        echo -e "${RED}   Clients: ${FAILED[*]}${NC}"
    fi
    
    echo -e "${BLUE}⏱️  Total time: ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Show output locations
    if [ ${#SUCCESSFUL[@]} -gt 0 ]; then
        echo -e "${GREEN}📱 Output files:${NC}"
        for CLIENT in "${SUCCESSFUL[@]}"; do
            if [ "$BUILD_TYPE" == "apk" ]; then
                # Show split APKs
                APK_FOUND=false
                for ABI in arm64-v8a armeabi-v7a x86_64; do
                    OUTPUT_PREFIX="${CLIENT^^}_V${VERSION_NAME}"
                    APK_PATH="${APK_OUTPUT_DIR}/${OUTPUT_PREFIX}_${MODE}_${ABI}.apk"
                    if [ -f "$APK_PATH" ]; then
                        APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
                        echo -e "  ${GREEN}✓${NC} $CLIENT ($ABI): $APK_PATH ($APK_SIZE)"
                        APK_FOUND=true
                    fi
                done
                # Also check universal APK (when building universal or as fallback)
                OUTPUT_PREFIX="${CLIENT^^}_V${VERSION_NAME}"
                UNIVERSAL_APK_PATH="${APK_OUTPUT_DIR}/${OUTPUT_PREFIX}_${MODE}.apk"
                if [ -f "$UNIVERSAL_APK_PATH" ]; then
                    APK_SIZE=$(du -h "$UNIVERSAL_APK_PATH" | cut -f1)
                    echo -e "  ${GREEN}✓${NC} $CLIENT (Universal): $UNIVERSAL_APK_PATH ($APK_SIZE)"
                    APK_FOUND=true
                fi
                if [ "$APK_FOUND" == false ]; then
                    echo -e "  ${YELLOW}⚠️${NC} $CLIENT: APK not found"
                fi
            elif [ "$BUILD_TYPE" == "appbundle" ]; then
                AAB_PATH="build/app/outputs/bundle/${CLIENT}Release/app-$CLIENT-release.aab"
                if [ -f "$AAB_PATH" ]; then
                    AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
                    echo -e "  ${GREEN}✓${NC} $CLIENT: $AAB_PATH ($AAB_SIZE)"
                fi
            fi
        done
        echo ""
    fi
    
    # Exit with error if any builds failed
    if [ ${#FAILED[@]} -gt 0 ]; then
        exit 1
    fi
else
    # Build single client
    if ! build_flavor "$FLAVOR" "$BUILD_TYPE" "$MODE" "false" "$BUILD_UNIVERSAL_APK"; then
        exit 1
    fi
fi
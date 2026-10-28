#!/bin/bash

# Script to run Flutter on iOS simulator with flavor
# Usage: bash scripts/run_ios_flavor.sh <flavor>
# Example: bash scripts/run_ios_flavor.sh vantage

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ $# -lt 1 ]; then
    echo -e "${RED}❌ Error: Flavor not specified${NC}"
    echo "Usage: bash scripts/run_ios_flavor.sh <flavor>"
    echo "  Available flavors: $(ls assets/brands | tr '\n' ' ')"
    exit 1
fi

FLAVOR=$1

# Any flavor with a brand.yaml is valid — no hardcoded list.
if [ ! -f "assets/brands/$FLAVOR/brand.yaml" ]; then
    echo -e "${RED}❌ Invalid flavor: $FLAVOR (assets/brands/$FLAVOR/brand.yaml not found)${NC}"
    echo "  Available flavors: $(ls assets/brands | tr '\n' ' ')"
    exit 1
fi

echo -e "${GREEN}🎨 Using flavor: $FLAVOR${NC}"
echo ""

# Step 1: Prepare the flavor. Writes ios/Flutter/Brand.xcconfig (bundle id,
# display name, dart-defines, deep-link host + entitlements) and app icons.
echo -e "${YELLOW}📱 Step 1: Preparing iOS flavor configuration...${NC}"
if ! dart run scripts/prepare_flavor.dart "$FLAVOR"; then
    echo -e "${RED}❌ Failed to prepare flavor $FLAVOR${NC}"
    exit 1
fi
echo ""

# Step 2: Find iOS simulator
echo -e "${YELLOW}🔍 Step 2: Detecting iOS simulator...${NC}"
DEVICES_OUTPUT=$(flutter devices 2>/dev/null)

# Parse iOS devices
IOS_DEVICE=""
IOS_DEVICE_NAME=""

while IFS= read -r line; do
    # Skip header lines and empty lines
    if [[ "$line" =~ ^Found.*devices ]] || [[ "$line" =~ ^$ ]] || [[ "$line" =~ ^Checking ]] || [[ "$line" =~ ^Error: ]] || [[ "$line" =~ ^Run.*flutter ]]; then
        continue
    fi
    
    # Check for iOS devices (iPhone, iPad, simulator)
    if [[ "$line" == *iPhone* ]] || [[ "$line" == *iPad* ]] || [[ "$line" == *ios* ]] || [[ "$line" == *simulator* ]] || [[ "$line" == *iOS* ]]; then
        # Extract device ID (second field after •)
        if [[ "$line" =~ \•[[:space:]]*([^[:space:]]+)[[:space:]]+\•[[:space:]]*(.+)[[:space:]]+\• ]]; then
            IOS_DEVICE="${BASH_REMATCH[1]}"
            IOS_DEVICE_NAME="${BASH_REMATCH[2]}"
            break
        fi
    fi
done <<< "$DEVICES_OUTPUT"

# If not found, try simpler parsing
if [ -z "$IOS_DEVICE" ]; then
    IOS_LINE=$(echo "$DEVICES_OUTPUT" | grep -E "iPhone|iPad|ios|simulator|iOS" | head -1)
    if [ -n "$IOS_LINE" ]; then
        IOS_DEVICE=$(echo "$IOS_LINE" | awk -F' • ' '{print $2}' | awk '{print $1}' | xargs)
        IOS_DEVICE_NAME=$(echo "$IOS_LINE" | awk -F' • ' '{print $3}' | xargs)
    fi
fi

# If still no device found, check if we need to boot simulator
if [ -z "$IOS_DEVICE" ]; then
    echo -e "${YELLOW}⚠️  No iOS simulator found. Checking available simulators...${NC}"
    
    # List available simulators
    SIMULATORS=$(xcrun simctl list devices available | grep -E "iPhone|iPad" | head -5)
    
    if [ -z "$SIMULATORS" ]; then
        echo -e "${RED}❌ No iOS simulators available. Please create one in Xcode.${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📱 Available simulators:${NC}"
    echo "$SIMULATORS" | head -3
    echo ""
    echo -e "${YELLOW}💡 Tip: Boot a simulator manually or use:${NC}"
    echo "   open -a Simulator"
    echo ""
    echo -e "${YELLOW}⏳ Waiting for simulator to be available...${NC}"
    
    # Wait up to 30 seconds for simulator to appear
    for i in {1..30}; do
        DEVICES_OUTPUT=$(flutter devices 2>/dev/null)
        IOS_DEVICE=$(echo "$DEVICES_OUTPUT" | grep -E "iPhone|iPad|ios|simulator|iOS" | head -1 | awk -F' • ' '{print $2}' | awk '{print $1}' | xargs)
        
        if [ -n "$IOS_DEVICE" ]; then
            IOS_DEVICE_NAME=$(echo "$DEVICES_OUTPUT" | grep -E "iPhone|iPad|ios|simulator|iOS" | head -1 | awk -F' • ' '{print $3}' | xargs)
            break
        fi
        sleep 1
        echo -n "."
    done
    echo ""
fi

if [ -z "$IOS_DEVICE" ]; then
    echo -e "${RED}❌ No iOS simulator found. Please start a simulator first.${NC}"
    echo "   Run: open -a Simulator"
    exit 1
fi

echo -e "${GREEN}✅ Found iOS simulator: $IOS_DEVICE_NAME ($IOS_DEVICE)${NC}"
echo ""

# Step 3: Run Flutter with --dart-define instead of --flavor
# Flutter iOS doesn't support --flavor when only default Runner scheme exists
# Flavor is passed via --dart-define and handled by Flutter's flavor system
echo -e "${GREEN}🚀 Step 3: Running app with flavor '$FLAVOR' on iOS simulator...${NC}"
echo -e "${BLUE}   Note: Using --dart-define=FLAVOR instead of --flavor for iOS${NC}"
echo -e "${BLUE}   Flavor is passed to Flutter via environment variable${NC}"
echo ""

# Use --dart-define to pass flavor to Flutter (main.dart reads it from environment)
flutter run --dart-define=CLIENT="$FLAVOR" --dart-define=FLAVOR="$FLAVOR" -d "$IOS_DEVICE"


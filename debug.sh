#!/bin/bash

# Debug script for Flutter flavors with full logging and debugging
# This script automatically:
#   1. Prepares client assets
#   2. Runs the app in debug mode with verbose logging
#   3. Shows all logs including debug logs
#   4. Enables hot reload and debugging
#
# Usage: ./debug.sh {flavor} [device] [options]
# Example: ./debug.sh afx
# Example: ./debug.sh afx emulator-5554
# Example: ./debug.sh afx --verbose

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}❌ Error: Missing flavor argument${NC}"
    echo "Usage: ./debug.sh {flavor} [device] [options]"
    echo "  flavor: afx, pipze, onsa, tenax, profx"
    echo "  device: (optional) device ID from 'flutter devices'"
    echo "  options: --verbose (show verbose Flutter logs)"
    echo ""
    echo "Examples:"
    echo "  ./debug.sh afx"
    echo "  ./debug.sh afx emulator-5554"
    echo "  ./debug.sh afx --verbose"
    echo "  ./debug.sh pipze emulator-5554 --verbose"
    exit 1
fi

FLAVOR=$1
DEVICE=""
VERBOSE=false

# Parse remaining arguments
shift
while [ $# -gt 0 ]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            ;;
        *)
            if [ -z "$DEVICE" ]; then
                DEVICE=$1
            fi
            ;;
    esac
    shift
done

echo -e "${GREEN}🐛 Debug Mode: $FLAVOR flavor${NC}"
if [ -n "$DEVICE" ]; then
    echo -e "${BLUE}📱 Device: $DEVICE${NC}"
fi
if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}📋 Verbose logging enabled${NC}"
fi
echo ""

# Step 1: Prepare assets
echo -e "${YELLOW}📦 Step 1: Preparing client assets...${NC}"
dart run scripts/prepare_flavor.dart $FLAVOR
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to prepare assets${NC}"
    exit 1
fi

# Step 2: List available devices if no device specified
if [ -z "$DEVICE" ]; then
    echo ""
    echo -e "${YELLOW}🔍 Available devices:${NC}"
    flutter devices
    echo ""
    echo -e "${BLUE}💡 Tip: Specify a device ID to skip this step next time${NC}"
    echo -e "${BLUE}   Example: ./debug.sh $FLAVOR emulator-5554${NC}"
    echo ""
fi

# Step 3: Run in debug mode
echo -e "\n${YELLOW}🐛 Step 2: Running app in DEBUG mode...${NC}"
echo -e "${GREEN}✅ All logs enabled (Trading, Chart, WebSocket, API, Order, Price, Debug)${NC}"
echo -e "${GREEN}✅ Hot reload enabled${NC}"
echo -e "${GREEN}✅ Debugger attached${NC}"
echo ""

# Build flutter run command
FLUTTER_CMD="flutter run"
FLUTTER_CMD="$FLUTTER_CMD --flavor $FLAVOR"
FLUTTER_CMD="$FLUTTER_CMD -t lib/main.dart"
FLUTTER_CMD="$FLUTTER_CMD --dart-define=FLAVOR=$FLAVOR"
FLUTTER_CMD="$FLUTTER_CMD --debug"

if [ -n "$DEVICE" ]; then
    FLUTTER_CMD="$FLUTTER_CMD -d $DEVICE"
fi

if [ "$VERBOSE" = true ]; then
    FLUTTER_CMD="$FLUTTER_CMD --verbose"
fi

echo -e "${BLUE}🚀 Command: $FLUTTER_CMD${NC}"
echo ""
echo -e "${YELLOW}💡 Debug Tips:${NC}"
echo -e "  • Press 'r' to hot reload"
echo -e "  • Press 'R' to hot restart"
echo -e "  • Press 'q' to quit"
echo -e "  • Press 'h' for help"
echo -e "  • Check logs below for detailed information"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Execute the command
eval $FLUTTER_CMD


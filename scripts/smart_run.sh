#!/bin/bash

# Smart Run Script for Flutter App
# Auto-detects flavor from main.dart, checks for devices, launches emulators if needed,
# and runs the app with the correct flavor on the selected device

set -e

MAIN_DART="lib/main.dart"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Extract flavor from main.dart (ignore commented lines)
FLAVOR=$(grep -E "^[[:space:]]*FlavorConfig\.(pipze|octa|fleza|tenax|onsa|profx|afx)" "$MAIN_DART" | grep -v "^[[:space:]]*//" | head -1 | sed -E 's/.*FlavorConfig\.([a-z]+).*/\1/')

if [ -z "$FLAVOR" ]; then
    echo -e "${RED}⚠️  Could not detect flavor from $MAIN_DART${NC}"
    echo "   Make sure FlavorConfig.{flavor} is set in main.dart"
    exit 1
fi

echo -e "${GREEN}🎨 Detected flavor: $FLAVOR${NC}"
echo ""

# Function to wait for device to be ready
wait_for_device() {
    local device_id=$1
    local max_attempts=30
    local attempt=0
    
    echo -e "${YELLOW}⏳ Waiting for device to be ready...${NC}"
    while [ $attempt -lt $max_attempts ]; do
        if flutter devices 2>/dev/null | grep -q "$device_id"; then
            echo -e "${GREEN}✅ Device is ready!${NC}"
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
        echo -n "."
    done
    echo ""
    echo -e "${RED}❌ Device did not become ready in time${NC}"
    return 1
}

# Get list of available devices
echo -e "${BLUE}📱 Checking for available devices...${NC}"
DEVICES_OUTPUT=$(flutter devices 2>/dev/null)

# Parse devices into arrays
ANDROID_DEVICES=()
IOS_DEVICES=()
OTHER_DEVICES=()

while IFS= read -r line; do
    # Skip header lines and empty lines
    if [[ "$line" =~ ^Found.*devices ]] || [[ "$line" =~ ^$ ]] || [[ "$line" =~ ^Checking ]] || [[ "$line" =~ ^Error: ]] || [[ "$line" =~ ^Run.*flutter ]]; then
        continue
    fi
    
    # Extract device ID and info
    if [[ "$line" =~ ^[[:space:]]+([^[:space:]]+)[[:space:]]+\•[[:space:]]+(.+)[[:space:]]+\•[[:space:]]+.* ]]; then
        device_id="${BASH_REMATCH[1]}"
        device_info="${BASH_REMATCH[2]}"
        
        # Determine device type
        if [[ "$device_id" == emulator-* ]] || [[ "$device_info" == *android* ]] || [[ "$device_info" == *Android* ]]; then
            ANDROID_DEVICES+=("$device_id|$device_info")
        elif [[ "$device_info" == *iPhone* ]] || [[ "$device_info" == *iPad* ]] || [[ "$device_id" == *ios* ]] || [[ "$device_info" == *iOS* ]]; then
            IOS_DEVICES+=("$device_id|$device_info")
        else
            OTHER_DEVICES+=("$device_id|$device_info")
        fi
    fi
done <<< "$DEVICES_OUTPUT"

TOTAL_DEVICES=$((${#ANDROID_DEVICES[@]} + ${#IOS_DEVICES[@]} + ${#OTHER_DEVICES[@]}))

SELECTED_DEVICE=""
SELECTED_NAME=""
IS_IOS=false
IS_ANDROID=false

# If no devices found, check for available emulators
if [ $TOTAL_DEVICES -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No devices found. Checking for available emulators...${NC}"
    echo ""
    
    EMULATORS_OUTPUT=$(flutter emulators 2>/dev/null)
    
    if [ -z "$EMULATORS_OUTPUT" ] || ! echo "$EMULATORS_OUTPUT" | grep -q "available emulators"; then
        echo -e "${RED}❌ No devices or emulators found.${NC}"
        echo "   Please start an emulator or connect a device manually."
        exit 1
    fi
    
    # Parse emulators
    IOS_EMULATORS=()
    ANDROID_EMULATORS=()
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]+\•[[:space:]]+(.+)[[:space:]]+\•.* ]]; then
            emulator_id="${BASH_REMATCH[1]}"
            emulator_name="${BASH_REMATCH[2]}"
            
            if [[ "$emulator_id" == *ios* ]] || [[ "$emulator_name" == *iOS* ]] || [[ "$emulator_name" == *iPhone* ]] || [[ "$emulator_name" == *iPad* ]]; then
                IOS_EMULATORS+=("$emulator_id|$emulator_name")
            elif [[ "$emulator_id" == *android* ]] || [[ "$emulator_name" == *Android* ]] || [[ "$emulator_name" == *Pixel* ]] || [[ "$emulator_name" == *emulator* ]]; then
                ANDROID_EMULATORS+=("$emulator_id|$emulator_name")
            fi
        fi
    done <<< "$EMULATORS_OUTPUT"
    
    TOTAL_EMULATORS=$((${#IOS_EMULATORS[@]} + ${#ANDROID_EMULATORS[@]}))
    
    if [ $TOTAL_EMULATORS -eq 0 ]; then
        echo -e "${RED}❌ No emulators available.${NC}"
        echo "   Please create an emulator first: flutter emulators --create"
        exit 1
    fi
    
    # Prompt user to select emulator
    echo -e "${BLUE}📱 Available emulators:${NC}"
    echo ""
    
    INDEX=1
    ALL_EMULATORS=()
    
    # List iOS emulators
    for emulator in "${IOS_EMULATORS[@]}"; do
        id=$(echo "$emulator" | cut -d'|' -f1)
        name=$(echo "$emulator" | cut -d'|' -f2)
        echo "  [$INDEX] 🍎 iOS: $name ($id)"
        ALL_EMULATORS+=("$id|$name|ios")
        INDEX=$((INDEX + 1))
    done
    
    # List Android emulators
    for emulator in "${ANDROID_EMULATORS[@]}"; do
        id=$(echo "$emulator" | cut -d'|' -f1)
        name=$(echo "$emulator" | cut -d'|' -f2)
        echo "  [$INDEX] 🤖 Android: $name ($id)"
        ALL_EMULATORS+=("$id|$name|android")
        INDEX=$((INDEX + 1))
    done
    
    echo ""
    read -p "Select emulator to launch [1-$((INDEX - 1))]: " CHOICE
    
    if [ -z "$CHOICE" ] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#ALL_EMULATORS[@]} ]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
    fi
    
    SELECTED_EMULATOR="${ALL_EMULATORS[$((CHOICE - 1))]}"
    EMULATOR_ID=$(echo "$SELECTED_EMULATOR" | cut -d'|' -f1)
    EMULATOR_NAME=$(echo "$SELECTED_EMULATOR" | cut -d'|' -f2)
    EMULATOR_TYPE=$(echo "$SELECTED_EMULATOR" | cut -d'|' -f3)
    
    echo ""
    echo -e "${GREEN}🚀 Launching $EMULATOR_NAME...${NC}"
    flutter emulators --launch "$EMULATOR_ID"
    
    if [ "$EMULATOR_TYPE" == "ios" ]; then
        IS_IOS=true
        # Wait for iOS simulator to boot
        sleep 5
        # Get the device ID after launch
        SELECTED_DEVICE=$(flutter devices 2>/dev/null | grep -E "iPhone|iPad|ios" | head -1 | awk '{print $1}' | xargs)
    else
        IS_ANDROID=true
        # Wait for Android emulator to boot
        sleep 10
        # Get the device ID after launch
        SELECTED_DEVICE=$(flutter devices 2>/dev/null | grep -E "emulator-" | head -1 | awk '{print $1}' | xargs)
    fi
    
    if [ -z "$SELECTED_DEVICE" ]; then
        echo -e "${YELLOW}⏳ Waiting for emulator to boot...${NC}"
        wait_for_device "$EMULATOR_ID" || {
            echo -e "${RED}❌ Failed to detect device after launch${NC}"
            exit 1
        }
        # Try to get device ID again
        if [ "$EMULATOR_TYPE" == "ios" ]; then
            SELECTED_DEVICE=$(flutter devices 2>/dev/null | grep -E "iPhone|iPad|ios" | head -1 | awk '{print $1}' | xargs)
        else
            SELECTED_DEVICE=$(flutter devices 2>/dev/null | grep -E "emulator-" | head -1 | awk '{print $1}' | xargs)
        fi
    fi
    
    SELECTED_NAME="$EMULATOR_NAME"
    echo -e "${GREEN}✅ Emulator launched: $SELECTED_NAME ($SELECTED_DEVICE)${NC}"
    
elif [ $TOTAL_DEVICES -eq 1 ]; then
    # Only one device, use it automatically
    if [ ${#ANDROID_DEVICES[@]} -eq 1 ]; then
        SELECTED_DEVICE=$(echo "${ANDROID_DEVICES[0]}" | cut -d'|' -f1)
        SELECTED_NAME=$(echo "${ANDROID_DEVICES[0]}" | cut -d'|' -f2)
        IS_ANDROID=true
    elif [ ${#IOS_DEVICES[@]} -eq 1 ]; then
        SELECTED_DEVICE=$(echo "${IOS_DEVICES[0]}" | cut -d'|' -f1)
        SELECTED_NAME=$(echo "${IOS_DEVICES[0]}" | cut -d'|' -f2)
        IS_IOS=true
    else
        SELECTED_DEVICE=$(echo "${OTHER_DEVICES[0]}" | cut -d'|' -f1)
        SELECTED_NAME=$(echo "${OTHER_DEVICES[0]}" | cut -d'|' -f2)
    fi
    echo -e "${GREEN}✅ Auto-selected device: $SELECTED_NAME ($SELECTED_DEVICE)${NC}"
else
    # Multiple devices, prompt user
    echo -e "${BLUE}📱 Available devices:${NC}"
    echo ""
    
    INDEX=1
    ALL_DEVICES=()
    
    # List Android devices
    for device in "${ANDROID_DEVICES[@]}"; do
        id=$(echo "$device" | cut -d'|' -f1)
        name=$(echo "$device" | cut -d'|' -f2)
        echo "  [$INDEX] 🤖 Android: $name ($id)"
        ALL_DEVICES+=("$id|$name|android")
        INDEX=$((INDEX + 1))
    done
    
    # List iOS devices
    for device in "${IOS_DEVICES[@]}"; do
        id=$(echo "$device" | cut -d'|' -f1)
        name=$(echo "$device" | cut -d'|' -f2)
        echo "  [$INDEX] 🍎 iOS: $name ($id)"
        ALL_DEVICES+=("$id|$name|ios")
        INDEX=$((INDEX + 1))
    done
    
    # List other devices
    for device in "${OTHER_DEVICES[@]}"; do
        id=$(echo "$device" | cut -d'|' -f1)
        name=$(echo "$device" | cut -d'|' -f2)
        echo "  [$INDEX] 💻 Other: $name ($id)"
        ALL_DEVICES+=("$id|$name|other")
        INDEX=$((INDEX + 1))
    done
    
    echo ""
    read -p "Select device number [1-$((INDEX - 1))]: " CHOICE
    
    if [ -z "$CHOICE" ] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#ALL_DEVICES[@]} ]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
    fi
    
    SELECTED_DEVICE_INFO="${ALL_DEVICES[$((CHOICE - 1))]}"
    SELECTED_DEVICE=$(echo "$SELECTED_DEVICE_INFO" | cut -d'|' -f1)
    SELECTED_NAME=$(echo "$SELECTED_DEVICE_INFO" | cut -d'|' -f2)
    DEVICE_TYPE=$(echo "$SELECTED_DEVICE_INFO" | cut -d'|' -f3)
    
    if [ "$DEVICE_TYPE" == "ios" ]; then
        IS_IOS=true
    elif [ "$DEVICE_TYPE" == "android" ]; then
        IS_ANDROID=true
    fi
    
    echo -e "${GREEN}✅ Selected device: $SELECTED_NAME ($SELECTED_DEVICE)${NC}"
fi

# Step 1: Prepare assets before running
echo ""
echo -e "${YELLOW}📦 Preparing client assets for $FLAVOR...${NC}"
if ! dart run scripts/prepare_flavor.dart "$FLAVOR"; then
    echo -e "${RED}❌ Failed to prepare assets for $FLAVOR${NC}"
    exit 1
fi
echo ""

# Build flutter run command
# For iOS, use --dart-define instead of --flavor
# For Android, use --flavor
if [ "$IS_ANDROID" = true ]; then
    echo ""
    echo -e "${BLUE}🤖 Android device detected. Using flavor: $FLAVOR${NC}"
    FLUTTER_CMD="flutter run --flavor $FLAVOR -d \"$SELECTED_DEVICE\""
else
    echo ""
    echo -e "${BLUE}🍎 iOS device detected. Using flavor: $FLAVOR${NC}"
    echo -e "${BLUE}   Updating iOS configuration...${NC}"
    bash scripts/update_ios_flavor.sh "$FLAVOR" 2>/dev/null || true
    # Use --dart-define for iOS instead of --flavor
    FLUTTER_CMD="flutter run --dart-define=FLAVOR=$FLAVOR -d \"$SELECTED_DEVICE\""
fi

# Run the app
echo ""
echo -e "${GREEN}🚀 Running app with flavor '$FLAVOR' on $SELECTED_NAME...${NC}"
echo ""

eval $FLUTTER_CMD


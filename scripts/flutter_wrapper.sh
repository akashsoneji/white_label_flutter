#!/bin/bash

# Universal Flutter wrapper that handles iOS flavor conversion automatically
# This can be aliased to 'flutter' to automatically handle iOS flavor issues
#
# Usage:
#   alias flutter='bash /path/to/scripts/flutter_wrapper.sh'
#   Then: flutter run --flavor pipze  (works for both iOS and Android)

# Check if this is a 'run' command with --flavor
if [ "$1" == "run" ] && [[ "$*" == *"--flavor"* ]]; then
    # Extract flavor and device from arguments
    FLAVOR=""
    DEVICE=""
    ARGS=("$@")
    SKIP_NEXT=false
    
    # Parse arguments
    for i in "${!ARGS[@]}"; do
        if [ "$SKIP_NEXT" == true ]; then
            SKIP_NEXT=false
            continue
        fi
        
        if [ "${ARGS[$i]}" == "--flavor" ] && [ $((i+1)) -lt ${#ARGS[@]} ]; then
            FLAVOR="${ARGS[$((i+1))]}"
            SKIP_NEXT=true
        elif [ "${ARGS[$i]}" == "-d" ] || [ "${ARGS[$i]}" == "--device" ]; then
            if [ $((i+1)) -lt ${#ARGS[@]} ]; then
                DEVICE="${ARGS[$((i+1))]}"
                SKIP_NEXT=true
            fi
        fi
    done
    
    if [ -n "$FLAVOR" ]; then
        # Detect if target device is iOS
        IS_IOS=false
        if [ -n "$DEVICE" ]; then
            # Check if specified device is iOS
            DEVICES_OUTPUT=$(flutter devices 2>/dev/null)
            if echo "$DEVICES_OUTPUT" | grep "$DEVICE" | grep -qE "iPhone|iPad|ios|simulator|iOS"; then
                IS_IOS=true
            fi
        else
            # Auto-detect: check if any iOS device is available
            DEVICES_OUTPUT=$(flutter devices 2>/dev/null)
            if echo "$DEVICES_OUTPUT" | grep -qE "iPhone|iPad|ios|simulator|iOS"; then
                IS_IOS=true
                # Auto-select first iOS device
                DEVICE=$(echo "$DEVICES_OUTPUT" | grep -E "iPhone|iPad|ios|simulator|iOS" | head -1 | awk -F' • ' '{print $2}' | awk '{print $1}' | xargs)
            fi
        fi
        
        if [ "$IS_IOS" = true ]; then
            # iOS: Update config and use --dart-define
            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            echo "🍎 iOS detected. Converting --flavor to --dart-define for iOS..."
            bash "$SCRIPT_DIR/update_ios_flavor.sh" "$FLAVOR" 2>/dev/null || true
            
            # Build new command with --dart-define instead of --flavor
            NEW_ARGS=("run")
            SKIP_NEXT=false
            for i in "${!ARGS[@]}"; do
                if [ "$SKIP_NEXT" == true ]; then
                    SKIP_NEXT=false
                    continue
                fi
                
                if [ "${ARGS[$i]}" == "--flavor" ]; then
                    NEW_ARGS+=("--dart-define=FLAVOR=$FLAVOR")
                    SKIP_NEXT=true
                else
                    NEW_ARGS+=("${ARGS[$i]}")
                fi
            done
            
            # Add device if we auto-detected one
            if [ -n "$DEVICE" ] && [[ ! " ${NEW_ARGS[@]} " =~ " -d " ]] && [[ ! " ${NEW_ARGS[@]} " =~ " --device " ]]; then
                NEW_ARGS+=("-d")
                NEW_ARGS+=("$DEVICE")
            fi
            
            exec flutter "${NEW_ARGS[@]}"
        else
            # Android: Use --flavor as normal
            exec flutter "$@"
        fi
    else
        # No flavor, pass through
        exec flutter "$@"
    fi
else
    # Not a 'run' command with --flavor, pass through
    exec flutter "$@"
fi


#!/bin/bash

# Script to get the detected flavor from the file
# This is used by launch configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FLAVOR_FILE="${WORKSPACE_DIR}/.vscode/.detected_flavor.txt"

if [ -f "$FLAVOR_FILE" ]; then
    cat "$FLAVOR_FILE" | tr -d '\n'
else
    # Fallback: read from main.dart
    MAIN_DART="${WORKSPACE_DIR}/lib/main.dart"
    FLAVOR=$(grep -E "^[[:space:]]*FlavorConfig\.(pipze|octa|fleza|tenax|onsa|profx)" "$MAIN_DART" | grep -v "^[[:space:]]*//" | head -1 | sed -E 's/.*FlavorConfig\.([a-z]+).*/\1/')
    if [ -z "$FLAVOR" ]; then
        echo "profx"
    else
        echo "$FLAVOR"
    fi
fi


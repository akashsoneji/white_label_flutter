#!/bin/bash

# Script to prepare launch arguments by detecting flavor from main.dart
# This writes the flavor to a file that can be read by the launch configuration

MAIN_DART="lib/main.dart"

# Extract flavor from main.dart (ignore commented lines)
FLAVOR=$(grep -E "^[[:space:]]*FlavorConfig\.(pipze|octa|fleza|tenax|onsa|profx)" "$MAIN_DART" | grep -v "^[[:space:]]*//" | head -1 | sed -E 's/.*FlavorConfig\.([a-z]+).*/\1/')

if [ -z "$FLAVOR" ]; then
    FLAVOR="profx"  # Default
fi

# Write flavor to file for launch configuration to read
echo "$FLAVOR" > "${workspaceFolder}/.vscode/.flavor.txt" 2>/dev/null || echo "$FLAVOR" > ".vscode/.flavor.txt"

echo "$FLAVOR"


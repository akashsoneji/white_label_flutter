#!/bin/bash

# Script to get flavor from main.dart and output it for launch configuration
# This is used to set the flavor argument dynamically

MAIN_DART="lib/main.dart"

# Extract flavor from main.dart (ignore commented lines)
FLAVOR=$(grep -E "^[[:space:]]*FlavorConfig\.(pipze|octa|fleza|tenax|onsa|profx)" "$MAIN_DART" | grep -v "^[[:space:]]*//" | head -1 | sed -E 's/.*FlavorConfig\.([a-z]+).*/\1/')

if [ -z "$FLAVOR" ]; then
    FLAVOR="profx"  # Default
fi

echo "$FLAVOR"


#!/usr/bin/env bash
set -euo pipefail

# Generates Android launcher icon PNGs for the `vantage` product flavor.
#
# Usage:
#   bash scripts/set_vantage_android_launcher_icon.sh /absolute/or/relative/path/to/app_icon.png
#
# Requirements:
# - macOS: uses `sips` (built-in) for resizing.
#
# Output:
# - android/app/src/vantage/res/mipmap-*/ic_launcher.png
# - android/app/src/vantage/res/mipmap-*/ic_launcher_round.png

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_RES_DIR="$ROOT_DIR/android/app/src/vantage/res"

SRC_ICON="${1:-}"
if [[ -z "$SRC_ICON" ]]; then
  SRC_ICON="$ROOT_DIR/assets/clients/vantage/app_icon.png"
fi

if [[ ! -f "$SRC_ICON" ]]; then
  echo "Icon file not found (skipping): $SRC_ICON"
  exit 0
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "This script requires 'sips' (macOS)."
  exit 2
fi

# Keep bash 3.2 compatible (no associative arrays).
DENSITIES=(
  "mipmap-mdpi:48"
  "mipmap-hdpi:72"
  "mipmap-xhdpi:96"
  "mipmap-xxhdpi:144"
  "mipmap-xxxhdpi:192"
)

mkdir -p "$ANDROID_RES_DIR"

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "Generating Vantage launcher icons from: $SRC_ICON"
echo "Target: $ANDROID_RES_DIR"

for entry in "${DENSITIES[@]}"; do
  density="${entry%%:*}"
  size="${entry##*:}"
  out_dir="$ANDROID_RES_DIR/$density"
  mkdir -p "$out_dir"

  out_icon="$out_dir/ic_launcher.png"
  out_round="$out_dir/ic_launcher_round.png"

  # Resize to exact square size.
  cp "$SRC_ICON" "$TMP_DIR/src.png"
  sips -z "$size" "$size" "$TMP_DIR/src.png" --out "$out_icon" >/dev/null

  # Use same file for round unless you provide a separate round asset.
  cp "$out_icon" "$out_round"
done

echo "Done. You can now run with --flavor vantage."


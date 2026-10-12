#!/usr/bin/env bash
# Builds Resources/AppIcon.icns from Resources/AppIcon.png (1024×1024, transparent background).
# Resources/AppIcon-original.png is the artwork it was cut from.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="build/icon"
ICONSET="$WORK/AppIcon.iconset"
rm -rf "$WORK"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "wrote Resources/AppIcon.icns"

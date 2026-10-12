#!/usr/bin/env bash
# Builds the universal app and packages it as a drag-to-Applications DMG.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

APP_BUNDLE="build/MacNotch.app"
STAGING="build/dmg_staging"
OUTPUT="build/MacNotch-Installer.dmg"

rm -rf "$STAGING" "$OUTPUT"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "MacNotch" -srcfolder "$STAGING" -ov -format UDZO "$OUTPUT"
rm -rf "$STAGING"

cp "$OUTPUT" ./MacNotch-Installer.dmg
echo "DMG ready: $(pwd)/MacNotch-Installer.dmg"

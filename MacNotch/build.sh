#!/usr/bin/env bash
#
# Builds "MacNotch.app" as a universal binary (Apple silicon + Intel).
#
#   ./build.sh          build and ad-hoc sign
#   ./build.sh --run    build, then launch the app
#
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MacNotch"
EXE="MacNotch"
BUILD_DIR="build"
BUNDLE="$BUILD_DIR/$APP_NAME.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

RUN_APP=false
for argument in "$@"; do
  case "$argument" in
    --run) RUN_APP=true ;;
    *) echo "Unknown argument: $argument" >&2; exit 1 ;;
  esac
done

mkdir -p "$BUILD_DIR"

BINARIES=()
for arch in arm64 x86_64; do
  echo "==> Building for $arch"
  swift build -c release --arch "$arch" --product "$EXE"
  # Newer SwiftPM writes every arch to the same path, so copy each slice out before the next build.
  cp "$(swift build -c release --arch "$arch" --show-bin-path)/$EXE" "$BUILD_DIR/$EXE-$arch"
  BINARIES+=("$BUILD_DIR/$EXE-$arch")
done

if [ ! -f Resources/AppIcon.icns ]; then
  echo "==> Generating app icon"
  ./scripts/make_icon.sh
fi

echo "==> Building the Now Playing helper"
clang -dynamiclib -fobjc-arc -O2 -arch arm64 -arch x86_64 -mmacosx-version-min=13.0 \
  -framework AppKit -o "$BUILD_DIR/NowPlayingAdapter.dylib" Adapter/NowPlayingAdapter.m

echo "==> Assembling $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
lipo -create "${BINARIES[@]}" -output "$BUNDLE/Contents/MacOS/$EXE"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
cp "$BUILD_DIR/NowPlayingAdapter.dylib" "$BUNDLE/Contents/Resources/NowPlayingAdapter.dylib"
codesign --force --sign "$SIGN_IDENTITY" "$BUNDLE/Contents/Resources/NowPlayingAdapter.dylib"

codesign --force --sign "$SIGN_IDENTITY" "$BUNDLE"
codesign --verify --strict "$BUNDLE"

lipo -info "$BUNDLE/Contents/MacOS/$EXE"
echo "built $BUNDLE"

if "$RUN_APP"; then
  pkill -x "$EXE" 2>/dev/null || true
  sleep 0.5
  open "$BUNDLE"
fi

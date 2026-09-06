#!/bin/bash
set -euo pipefail
COMPANION_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$COMPANION_DIR"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
APP="$COMPANION_DIR/dist/Blocked.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/BlockedKey" "$APP/Contents/MacOS/BlockedKey"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${SIGNING_IDENTITY:--}" --options runtime \
  --entitlements Resources/Blocked.entitlements "$APP"
printf 'Built %s\n' "$APP"

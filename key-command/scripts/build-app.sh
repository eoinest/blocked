#!/bin/bash
set -euo pipefail
KEY_COMMAND_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KEY_COMMAND_DIR"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
mkdir -p dist
STAGING="$(mktemp -d "$KEY_COMMAND_DIR/dist/.KeyCommand-build.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Key Command.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/KeyCommand" "$APP/Contents/MacOS/KeyCommand"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp ../LICENSE "$APP/Contents/Resources/LICENSE.txt"
swift scripts/make-icon.swift "$STAGING/KeyCommand.iconset"
iconutil -c icns "$STAGING/KeyCommand.iconset" -o "$APP/Contents/Resources/KeyCommand.icns"
codesign --force --sign "${SIGNING_IDENTITY:--}" --options runtime \
  --entitlements Resources/KeyCommand.entitlements "$APP"
codesign --verify --deep --strict "$APP"
xcrun lipo "$APP/Contents/MacOS/KeyCommand" -verify_arch arm64 x86_64
rm -rf "$KEY_COMMAND_DIR/dist/Key Command.app"
mv "$APP" "$KEY_COMMAND_DIR/dist/Key Command.app"
printf 'Built %s\n' "$KEY_COMMAND_DIR/dist/Key Command.app"

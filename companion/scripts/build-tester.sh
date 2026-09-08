#!/bin/bash
set -euo pipefail
COMPANION_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$COMPANION_DIR"
swift build -c release --product ButtonTester --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
APP="$COMPANION_DIR/dist/Blocked Button Tester.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/ButtonTester" "$APP/Contents/MacOS/ButtonTester"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Blocked Button Tester</string>
<key>CFBundleIdentifier</key><string>io.github.eoinest.blocked-tester</string>
<key>CFBundleExecutable</key><string>ButtonTester</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built %s\n' "$APP"

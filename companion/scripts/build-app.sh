#!/bin/bash
set -euo pipefail
COMPANION_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_GH=1
export GH_OFFLINE="${GH_OFFLINE:-0}"
for arg in "$@"; do
  case "$arg" in
    --without-gh) BUNDLE_GH=0 ;;
    --offline) export GH_OFFLINE=1 ;;
    --help|-h)
      cat <<'HELP'
Usage: build-app.sh [--offline] [--without-gh]

Build a universal macOS app with a pinned, verified GitHub CLI by default.
  --offline     Use already cached GitHub CLI archives; never download them.
  --without-gh  Developer build only: omit GitHub CLI and use a local install.

GH_ARCHIVE_DIR overrides the archive cache (.build/gh-downloads by default).
SIGNING_IDENTITY selects the signing identity (default: ad-hoc local signing).
Distribution still requires a Developer ID identity and Apple notarization.
HELP
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
cd "$COMPANION_DIR"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
mkdir -p "$COMPANION_DIR/dist"
STAGING="$(mktemp -d "$COMPANION_DIR/dist/.Blocked-build.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Blocked.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/BlockedKey" "$APP/Contents/MacOS/BlockedKey"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp ../LICENSE "$APP/Contents/Resources/Blocked-LICENSE.txt"
swift scripts/make-icon.swift "$STAGING/Blocked.iconset"
iconutil -c icns "$STAGING/Blocked.iconset" -o "$APP/Contents/Resources/Blocked.icns"
if [[ "$BUNDLE_GH" == 1 ]]; then
  "$COMPANION_DIR/scripts/bundle-gh.sh" "$APP"
  # Sign nested executable first; the outer signature then seals its contents.
  codesign --force --sign "${SIGNING_IDENTITY:--}" --options runtime \
    "$APP/Contents/MacOS/gh"
else
  printf 'Developer build: GitHub CLI is not bundled.\n' >&2
fi
codesign --force --sign "${SIGNING_IDENTITY:--}" --options runtime \
  --entitlements Resources/Blocked.entitlements "$APP"
codesign --verify --deep --strict "$APP"
rm -rf "$COMPANION_DIR/dist/Blocked.app"
mv "$APP" "$COMPANION_DIR/dist/Blocked.app"
printf 'Built %s\n' "$COMPANION_DIR/dist/Blocked.app"

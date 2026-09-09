#!/bin/bash
# Package the app only, never the user's bindings, scripts, or command output.
set -euo pipefail
KEY_COMMAND_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY=-
NOTARY_PROFILE=
die() { printf '%s\n' "$*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign|--notarize-profile)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "Missing value for $1"
      case "$1" in --sign) IDENTITY="$2" ;; --notarize-profile) NOTARY_PROFILE="$2" ;; esac
      shift 2 ;;
    --help|-h)
      printf '%s\n' 'Usage: package-release.sh [--sign "Developer ID Application: Name (TEAMID)"] [--notarize-profile PROFILE]' \
        'Default: universal, ad-hoc signed beta DMG. Notarization only runs when explicitly requested.'
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
[[ "$IDENTITY" == - || "$IDENTITY" == 'Developer ID Application: '* ]] || die 'Use a Developer ID Application signing identity.'
[[ -z "$NOTARY_PROFILE" || "$IDENTITY" != - ]] || die 'Notarization requires Developer ID signing.'
SIGNING_IDENTITY="$IDENTITY" "$KEY_COMMAND_DIR/scripts/build-app.sh"
DIST="$KEY_COMMAND_DIR/dist"
STAGING="$(mktemp -d "$DIST/.KeyCommand-package.XXXXXX")"
MOUNT="$STAGING/mounted"
MOUNTED=0
cleanup() {
  if [[ "$MOUNTED" == 1 ]]; then hdiutil detach "$MOUNT" >/dev/null 2>&1 || true; fi
  rm -rf "$STAGING"
}
trap cleanup EXIT
mkdir -p "$STAGING/payload" "$MOUNT"
APP="$STAGING/payload/Key Command.app"
ditto "$DIST/Key Command.app" "$APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" == com.eoinest.keycommand ]] || die 'Unexpected app identity.'
xcrun lipo "$APP/Contents/MacOS/KeyCommand" -verify_arch arm64 x86_64
[[ -s "$APP/Contents/Resources/LICENSE.txt" ]] || die 'Missing license.'
if [[ "$IDENTITY" != - ]]; then
  codesign --force --sign "$IDENTITY" --timestamp --options runtime \
    --entitlements "$KEY_COMMAND_DIR/Resources/KeyCommand.entitlements" "$APP"
fi
codesign --verify --deep --strict "$APP"
notarize() {
  local result="$DIST/KeyCommand-$VERSION-$2-notary.json"
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" \
    --wait --timeout 30m --output-format json > "$result"
  [[ "$(plutil -extract status raw -o - "$result")" == Accepted ]] || die "Apple did not accept $2. See $result"
}
if [[ -n "$NOTARY_PROFILE" ]]; then
  ditto -c -k --keepParent "$APP" "$STAGING/KeyCommand.zip"
  notarize "$STAGING/KeyCommand.zip" app
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose "$APP"
fi
ln -s /Applications "$STAGING/payload/Applications"
cp "$KEY_COMMAND_DIR/Resources/Start Here.txt" "$STAGING/payload/Start Here.txt"
NAME="KeyCommand-$VERSION-beta.dmg"
if [[ -n "$NOTARY_PROFILE" ]]; then
  NAME="KeyCommand-$VERSION.dmg"
  python3 - "$STAGING/payload/Start Here.txt" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text(); a=s.index('PRIVATE BETA / FIRST OPEN'); b=s.index('\n\n',a)
p.write_text(s[:a]+'FIRST OPEN\nThis release is Developer ID signed and notarized by Apple. Confirm Open if macOS asks.'+s[b:])
PY
fi
DMG="$STAGING/$NAME"
hdiutil create -volname 'Key Command' -srcfolder "$STAGING/payload" -ov -format UDZO "$DMG"
if [[ "$IDENTITY" != - ]]; then codesign --sign "$IDENTITY" --timestamp "$DMG"; fi
if [[ -n "$NOTARY_PROFILE" ]]; then
  notarize "$DMG" dmg
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi
hdiutil verify "$DMG"
hdiutil attach "$DMG" -readonly -nobrowse -mountpoint "$MOUNT" >/dev/null
MOUNTED=1
[[ "$(readlink "$MOUNT/Applications")" == /Applications ]] || die 'Missing Applications shortcut.'
cmp "$STAGING/payload/Start Here.txt" "$MOUNT/Start Here.txt"
codesign --verify --deep --strict "$MOUNT/Key Command.app"
cmp "$APP/Contents/MacOS/KeyCommand" "$MOUNT/Key Command.app/Contents/MacOS/KeyCommand"
hdiutil detach "$MOUNT" >/dev/null
MOUNTED=0
mv -f "$DMG" "$DIST/$NAME"
(cd "$DIST" && shasum -a 256 "$NAME" > "$NAME.sha256")
printf 'Packaged %s\n' "$DIST/$NAME"
if [[ -z "$NOTARY_PROFILE" ]]; then printf 'Private beta: not Apple-notarized. See Start Here.txt.\n'; fi

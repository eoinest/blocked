#!/bin/bash
# Build and package only generated application files, never local user data.
set -euo pipefail
COMPANION_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=0.3.0
OFFLINE=0
IDENTITY=-
NOTARY_PROFILE=
NOTARY_KEYCHAIN=
die() { printf '%s\n' "$*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) OFFLINE=1; shift ;;
    --sign|--notarize-profile|--notary-keychain)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "Missing value for $1"
      case "$1" in
        --sign) IDENTITY="$2" ;;
        --notarize-profile) NOTARY_PROFILE="$2" ;;
        --notary-keychain) NOTARY_KEYCHAIN="$2" ;;
      esac
      shift 2 ;;
    --help|-h)
      cat <<'HELP'
Usage: package-release.sh [--offline]
       package-release.sh [--offline] --sign 'Developer ID Application: Name (TEAMID)'
         [--notarize-profile PROFILE [--notary-keychain /path/to/keychain]]

Default: build an ad-hoc signed Blocked-0.3.0-beta.dmg for private testing.
--offline uses cached GitHub CLI archives; it does not disable explicitly
requested notarization. Only --notarize-profile uploads artifacts to Apple.
The named notarytool credential profile must already exist in the Keychain.
No credentials, app preferences, or local GitHub configuration are packaged.
HELP
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
if [[ "$IDENTITY" != - && "$IDENTITY" != 'Developer ID Application: '* ]]; then
  die 'Distribution signing requires a Developer ID Application identity.'
fi
[[ -z "$NOTARY_PROFILE" || "$IDENTITY" != - ]] || die 'Notarization requires --sign with a Developer ID Application identity.'
[[ -z "$NOTARY_KEYCHAIN" || -n "$NOTARY_PROFILE" ]] || die '--notary-keychain requires --notarize-profile.'

BUILD_ARGS=()
if [[ "$OFFLINE" == 1 ]]; then BUILD_ARGS+=(--offline); fi
SIGNING_IDENTITY="$IDENTITY" "$COMPANION_DIR/scripts/build-app.sh" "${BUILD_ARGS[@]+${BUILD_ARGS[@]}}"
DIST="$COMPANION_DIR/dist"
STAGING="$(mktemp -d "$DIST/.Blocked-package.XXXXXX")"
MOUNT="$STAGING/mounted"
MOUNTED=0
cleanup() {
  if [[ "$MOUNTED" == 1 ]]; then hdiutil detach "$MOUNT" >/dev/null 2>&1 || true; fi
  rm -rf "$STAGING"
}
trap cleanup EXIT
mkdir -p "$STAGING/payload" "$MOUNT"
APP="$STAGING/payload/Blocked.app"
ditto "$DIST/Blocked.app" "$APP"
PLIST="$APP/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")" == "$VERSION" ]] || die 'App version does not match package version.'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")" == 13.0 ]] || die 'Expected macOS 13.0 deployment minimum.'
for executable in BlockedKey gh; do
  [[ -x "$APP/Contents/MacOS/$executable" ]] || die "Missing executable: $executable"
  xcrun lipo "$APP/Contents/MacOS/$executable" -verify_arch arm64 x86_64
done
[[ -s "$APP/Contents/Resources/ThirdPartyNotices/GitHubCLI-LICENSE.txt" ]] || die 'Missing bundled GitHub CLI license.'
"$APP/Contents/MacOS/gh" --version

if [[ "$IDENTITY" != - ]]; then
  # Timestamp both signatures explicitly for Developer ID distribution.
  codesign --force --sign "$IDENTITY" --timestamp --options runtime "$APP/Contents/MacOS/gh"
  codesign --force --sign "$IDENTITY" --timestamp --options runtime \
    --entitlements "$COMPANION_DIR/Resources/Blocked.entitlements" "$APP"
fi
codesign --verify --deep --strict "$APP"

notarize() {
  local artifact="$1" label="$2" result="$DIST/Blocked-$VERSION-$2-notary.json"
  local keychain_args=()
  if [[ -n "$NOTARY_KEYCHAIN" ]]; then keychain_args+=(--keychain "$NOTARY_KEYCHAIN"); fi
  xcrun notarytool submit "$artifact" --keychain-profile "$NOTARY_PROFILE" \
    "${keychain_args[@]+${keychain_args[@]}}" --wait --timeout 30m --output-format json > "$result"
  [[ "$(plutil -extract status raw -o - "$result")" == Accepted ]] || die "Apple did not accept $label. See $result"
}

if [[ -n "$NOTARY_PROFILE" ]]; then
  ditto -c -k --keepParent "$APP" "$STAGING/Blocked.zip"
  notarize "$STAGING/Blocked.zip" app
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose "$APP"
fi

ln -s /Applications "$STAGING/payload/Applications"
if [[ -n "$NOTARY_PROFILE" ]]; then
  # Replace the private-beta approval guidance only after app acceptance.
  awk '
    $0 == "PRIVATE BETA / FIRST OPEN" {
      found = 1; skip = 1
      print "FIRST OPEN"
      print "macOS may ask you to confirm opening this downloaded app. Click Open."
      print "This release is signed with Developer ID and notarized by Apple."
      next
    }
    skip { if ($0 == "") { skip = 0; print "" }; next }
    { print }
    END { if (!found) exit 1 }
  ' "$COMPANION_DIR/Resources/Start Here.txt" > "$STAGING/payload/Start Here.txt"
  NAME="Blocked-$VERSION.dmg"
else
  cp "$COMPANION_DIR/Resources/Start Here.txt" "$STAGING/payload/Start Here.txt"
  NAME="Blocked-$VERSION-beta.dmg"
fi
DMG="$STAGING/$NAME"
hdiutil create -volname 'Blocked' -srcfolder "$STAGING/payload" -ov -format UDZO "$DMG"
if [[ "$IDENTITY" != - ]]; then codesign --sign "$IDENTITY" --timestamp "$DMG"; fi
if [[ -n "$NOTARY_PROFILE" ]]; then
  notarize "$DMG" dmg
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG"
fi
hdiutil verify "$DMG"
hdiutil attach "$DMG" -readonly -nobrowse -mountpoint "$MOUNT" >/dev/null
MOUNTED=1
[[ "$(readlink "$MOUNT/Applications")" == /Applications ]] || die 'Missing Applications shortcut in DMG.'
cmp "$STAGING/payload/Start Here.txt" "$MOUNT/Start Here.txt"
codesign --verify --deep --strict "$MOUNT/Blocked.app"
for executable in BlockedKey gh; do
  cmp "$APP/Contents/MacOS/$executable" "$MOUNT/Blocked.app/Contents/MacOS/$executable"
done
hdiutil detach "$MOUNT" >/dev/null
MOUNTED=0
# Publish only after all requested signing/notarization and mounted checks pass.
mv -f "$DMG" "$DIST/$NAME"
(cd "$DIST" && shasum -a 256 "$NAME" > "$NAME.sha256")
printf 'Packaged %s\n' "$DIST/$NAME"
if [[ -z "$NOTARY_PROFILE" ]]; then
  printf 'Private beta: this DMG is not Apple-notarized. See Start Here.txt for first-open instructions.\n'
fi

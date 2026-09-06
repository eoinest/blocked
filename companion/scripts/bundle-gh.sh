#!/bin/bash
# Package verified upstream binaries. Does not sign in or install system tools.
set -euo pipefail
COMPANION_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=2.100.0
if [[ $# != 1 || ! -d "$1/Contents" ]]; then
  printf 'Usage: bundle-gh.sh /path/to/Blocked.app (Contents must exist)\n' >&2
  exit 2
fi
APP="$(cd "$1" && pwd)"
CACHE="${GH_ARCHIVE_DIR:-$COMPANION_DIR/.build/gh-downloads}"
mkdir -p "$CACHE"
CACHE="$(cd "$CACHE" && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/blocked-gh.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT

for arch in arm64 amd64; do
  archive="gh_${VERSION}_macOS_${arch}.zip"
  if [[ ! -f "$CACHE/$archive" ]]; then
    if [[ "${GH_OFFLINE:-0}" == 1 ]]; then
      printf 'Offline build needs cached archive: %s\n' "$CACHE/$archive" >&2
      exit 1
    fi
    curl --fail --location --proto '=https' --tlsv1.2 --retry 2 \
      --connect-timeout 20 --max-time 300 \
      "https://github.com/cli/cli/releases/download/v${VERSION}/$archive" \
      --output "$TEMP/$archive"
    # Check before adding downloads to the cache, and again on every cache use.
    expected="$(awk -v file="$archive" '$2 == file {print $1}' \
      "$COMPANION_DIR/scripts/gh-checksums.sha256")"
    [[ -n "$expected" ]]
    (cd "$TEMP" && printf '%s  %s\n' "$expected" "$archive" | shasum -a 256 --check)
    mv "$TEMP/$archive" "$CACHE/$archive"
  fi
  expected="$(awk -v file="$archive" '$2 == file {print $1}' \
    "$COMPANION_DIR/scripts/gh-checksums.sha256")"
  [[ -n "$expected" ]]
  (cd "$CACHE" && printf '%s  %s\n' "$expected" "$archive" | shasum -a 256 --check)
  # Extract only known members of the verified archive.
  unzip -p "$CACHE/$archive" "gh_${VERSION}_macOS_${arch}/bin/gh" > "$TEMP/gh-$arch"
  unzip -p "$CACHE/$archive" "gh_${VERSION}_macOS_${arch}/LICENSE" > "$TEMP/LICENSE-$arch"
  cmp "$TEMP/LICENSE-$arch" "$COMPANION_DIR/ThirdPartyNotices/GitHubCLI-LICENSE.txt"
done

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/ThirdPartyNotices"
xcrun lipo -create "$TEMP/gh-arm64" "$TEMP/gh-amd64" -output "$TEMP/gh"
xcrun lipo "$TEMP/gh" -verify_arch arm64 x86_64
chmod 755 "$TEMP/gh"
mv "$TEMP/gh" "$APP/Contents/MacOS/gh"
cp "$COMPANION_DIR/ThirdPartyNotices/GitHubCLI-LICENSE.txt" \
  "$COMPANION_DIR/ThirdPartyNotices/GitHubCLI.md" \
  "$APP/Contents/Resources/ThirdPartyNotices/"
printf 'Bundled GitHub CLI %s (arm64 + x86_64)\n' "$VERSION"

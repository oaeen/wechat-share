#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/微信记录.app"
VOLUME_NAME="微信记录"
TMP_ROOT="$(mktemp -d)"
STAGING="$TMP_ROOT/staging"

cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

if [[ "${SKIP_BUILD:-0}" != "1" || ! -d "$APP" ]]; then
    CONFIG=release "$ROOT/Scripts/build-app.sh"
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="${DMG_PATH:-$ROOT/dist/微信记录-$VERSION.dmg}"

mkdir -p "$STAGING"
ditto "$APP" "$STAGING/微信记录.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG" "$DMG.sha256"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG" >/dev/null

(
    cd "$(dirname "$DMG")"
    shasum -a 256 "$(basename "$DMG")"
) > "$DMG.sha256"
echo "$DMG"

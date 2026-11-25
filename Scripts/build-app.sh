#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIG:-release}"
APP_NAME="微信记录"
APP="$ROOT/dist/$APP_NAME.app"
APPEX="$APP/Contents/PlugIns/ChatArchiveShare.appex"

swift build -c "$CONFIG" --product ChatArchive
swift build -c "$CONFIG" --product ChatArchiveShare
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

ICONSET="$ROOT/.build/ChatArchive.iconset"
ICON="$ROOT/.build/AppIcon.icns"
rm -rf "$ICONSET" "$ICON"
swift "$ROOT/Scripts/make-icon.swift" "$ICONSET" "$ROOT/Resources/Icons/message-square-share.svg"
iconutil -c icns "$ICONSET" -o "$ICON"

rm -rf "$APP"
mkdir -p \
    "$APP/Contents/MacOS" \
    "$APP/Contents/Resources/Icons" \
    "$APP/Contents/Resources/Licenses" \
    "$APPEX/Contents/MacOS" \
    "$APPEX/Contents/Resources"

install -m 755 "$BIN_DIR/ChatArchive" "$APP/Contents/MacOS/ChatArchive"
install -m 644 "$ROOT/Resources/App-Info.plist" "$APP/Contents/Info.plist"
install -m 644 "$ICON" "$APP/Contents/Resources/AppIcon.icns"
install -m 644 "$ROOT/Resources/Icons/"*.svg "$APP/Contents/Resources/Icons/"
install -m 644 "$ROOT/Resources/Licenses/"* "$APP/Contents/Resources/Licenses/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

install -m 755 "$BIN_DIR/ChatArchiveShare" "$APPEX/Contents/MacOS/ChatArchiveShare"
install -m 644 "$ROOT/Resources/Share-Info.plist" "$APPEX/Contents/Info.plist"
install -m 644 "$ICON" "$APPEX/Contents/Resources/AppIcon.icns"

codesign --force --sign - --entitlements "$ROOT/Resources/ChatArchiveShare.entitlements" "$APPEX"
codesign --force --sign - "$APP"

codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist" "$APPEX/Contents/Info.plist"

echo "$APP"

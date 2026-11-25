#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift test
CONFIG="${CONFIG:-release}" "$ROOT/Scripts/build-app.sh"

APP="$ROOT/dist/微信记录.app"
APPEX="$APP/Contents/PlugIns/ChatArchiveShare.appex"

test -x "$APP/Contents/MacOS/ChatArchive"
test -x "$APPEX/Contents/MacOS/ChatArchiveShare"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements :- "$APPEX" 2>/dev/null | grep -q "com.apple.security.files.downloads.read-write"

echo "构建与签名校验通过。"
if pluginkit -m -p com.apple.share-services -i dev.chatarchive.app.share | grep -q dev.chatarchive.app.share; then
    echo "分享入口已注册。"
else
    echo "分享入口尚未注册；运行 Scripts/install.sh。"
fi

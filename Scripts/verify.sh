#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift test
CONFIG="${CONFIG:-release}" "$ROOT/Scripts/build-app.sh"

APP="$ROOT/dist/微信记录.app"
APPEX="$APP/Contents/PlugIns/ChatArchiveShare.appex"

if grep -R -n -E 'Image\(systemName:|NSImage\(systemSymbolName:' "$ROOT/Sources/ChatArchiveApp"; then
    echo "界面图标必须使用 Lucide，不能混入 SF Symbols。" >&2
    exit 1
fi

test -x "$APP/Contents/MacOS/ChatArchive"
test -x "$APPEX/Contents/MacOS/ChatArchiveShare"
test -f "$APP/Contents/Resources/Icons/message-square-share.svg"
test -f "$APP/Contents/Resources/Icons/message-square-text.svg"
test -f "$APP/Contents/Resources/Icons/trash-2.svg"
test -f "$APP/Contents/Resources/Licenses/Lucide-ISC.txt"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements :- "$APPEX" 2>/dev/null | grep -q "com.apple.security.files.downloads.read-write"

echo "构建与签名校验通过。"
if pluginkit -m -p com.apple.share-services -i dev.chatarchive.app.share | grep -q dev.chatarchive.app.share; then
    echo "分享入口已注册。"
else
    echo "分享入口尚未注册；运行 Scripts/install.sh。"
fi

#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/微信记录.app"
DEST_DIR="${INSTALL_DIR:-$HOME/Applications}"
DEST="$DEST_DIR/微信记录.app"
APPEX="$DEST/Contents/PlugIns/ChatArchiveShare.appex"
SHARE_ID="dev.chatarchive.app.share"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ ! -d "$APP" ]]; then
    echo "先运行 Scripts/build-app.sh。" >&2
    exit 1
fi

if pgrep -x ChatArchive >/dev/null 2>&1; then
    osascript -e 'tell application id "dev.chatarchive.app" to quit' >/dev/null 2>&1 || true
    sleep 1
fi

mkdir -p "$DEST_DIR"
ditto "$APP" "$DEST"
"$LSREGISTER" -f "$DEST"
pluginkit -a "$APPEX" >/dev/null 2>&1 || true

registered=false
for _ in {1..60}; do
    if pluginkit -m -p com.apple.share-services -i "$SHARE_ID" | grep -q "$SHARE_ID"; then
        registered=true
        break
    fi
    sleep 0.25
done

if [[ "$registered" != true ]]; then
    echo "分享扩展未出现在 pluginkit 列表，请检查代码签名与 Info.plist。" >&2
    exit 1
fi

pluginkit -e use -i "$SHARE_ID"
sleep 0.5

if ! pluginkit -m -v -p com.apple.share-services -i "$SHARE_ID" | grep -q "^+.*$SHARE_ID"; then
    echo "分享扩展已找到，但未能启用。" >&2
    exit 1
fi

echo "已安装：$DEST"
echo "退出并重新打开微信，随后在“转发到其他应用”中选择“微信记录”。"
open "$DEST"

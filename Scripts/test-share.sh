#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

NAME="ChatArchiveShareTest-$(date +%Y%m%d-%H%M%S).zip"
SOURCE="$TMP_DIR/$NAME"
EXPECTED="$HOME/Downloads/聊天存档/$NAME"

printf 'ChatArchive share test %s\n' "$(date -u +%FT%TZ)" > "$SOURCE"
swift "$ROOT/Scripts/share-test.swift" "$SOURCE"

if [[ ! -f "$EXPECTED" ]]; then
    echo "分享扩展没有写出文件：$EXPECTED" >&2
    exit 1
fi
if ! cmp -s "$SOURCE" "$EXPECTED"; then
    echo "分享扩展写出的内容与源文件不一致。" >&2
    exit 1
fi

echo "端到端分享通过：$EXPECTED"

# 图标资源

界面图标和应用图标的源文件来自 [Lucide Static 1.80.0](https://unpkg.com/lucide-static@1.80.0/)，使用 ISC 许可证。

| 文件 | 用途 |
| --- | --- |
| `message-square-share.svg` | 应用图标，同时用于生成 `.icns` |
| `message-square-text.svg` | 空状态 |
| `share-2.svg` | 转发 |
| `copy.svg` | 复制路径 |
| `check.svg` | 复制完成 |
| `folder-open.svg` | 在访达中显示 |
| `trash-2.svg` | 移到废纸篓 |
| `triangle-alert.svg` | 分享入口未注册 |
| `file-archive.svg` | ZIP 存档 |
| `file-text.svg` | 其他文件 |

界面通过 `Sources/ChatArchiveApp/LucideIcon.swift` 加载模板 SVG。应用图标由 `Scripts/make-icon.swift` 从 `message-square-share.svg` 生成。

完整许可证见 [`../Licenses/Lucide-ISC.txt`](../Licenses/Lucide-ISC.txt)，第三方来源说明见 [`../../THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md)。

# 微信记录

微信记录是一个 macOS 分享扩展，用于接收微信合并转发的聊天记录 ZIP，并保存到：

```text
~/Downloads/聊天存档/
```

应用只处理用户主动分享的文件。它不读取微信数据库，不注入微信进程，也不上传文件。

## 功能

- 从微信的“合并转发”菜单直接保存 ZIP，支持一次分享多个文件。
- 保留原始文件名。通用文件名会追加时间戳，同名文件自动编号，不覆盖旧存档。
- 先写入隐藏的临时文件，完成后再原子移动到最终路径，避免留下半个压缩包。
- 显示最近存档，并提供转发、复制完整路径、在访达中显示和移到废纸篓操作。
- 使用无标题栏窗口和轻量空状态动画；界面图标来自 Lucide。

## 环境要求

- macOS 14 或更新版本。
- 微信 macOS。分享入口已在微信 4.1.13 上验证。
- 从源码构建需要 Swift 6 工具链和 Xcode Command Line Tools。

## 安装

仓库当前不提供在线发布渠道。可以从源码构建，或生成 DMG 后安装。

### 从源码安装

```bash
Scripts/build-app.sh
Scripts/install.sh
```

`install.sh` 默认将应用安装到 `~/Applications/微信记录.app`，注册并启用分享扩展，然后打开应用。安装到系统目录时运行：

```bash
INSTALL_DIR=/Applications Scripts/install.sh
```

`~/Applications` 只对当前用户可见，不需要管理员权限。`/Applications` 供所有用户使用，写入时可能需要管理员权限。

### 生成 DMG

```bash
Scripts/make-dmg.sh
```

输出为 `dist/微信记录-<版本>.dmg`，同时生成 `.sha256` 校验文件。打开 DMG 后，将 `微信记录.app` 拖入 `Applications`。

这些构建使用本地 ad-hoc 签名，没有 Developer ID 签名和 Apple 公证。首次在其他机器上打开时，Gatekeeper 可能阻止启动。

## 使用

1. 首次安装后完全退出微信，再重新打开。
2. 在微信中多选消息，选择“合并转发”，再选择“其他应用”。
3. 在系统分享面板中点击“微信记录”。
4. 首次保存时允许 macOS 访问下载文件夹。ZIP 会保存到 `~/Downloads/聊天存档/`。

如果分享面板中没有“微信记录”，依次检查：

1. 完全退出微信并重新打开。关闭窗口不会刷新分享菜单缓存。
2. 在“系统设置 > 通用 > 登录项与扩展 > 共享”中启用“微信记录”。
3. 运行 `pluginkit -m -p com.apple.share-services -i dev.chatarchive.app.share`，确认扩展已注册。

## 开发

| 命令 | 用途 |
| --- | --- |
| `swift test` | 运行 `ChatArchiveCore` 的单元测试。 |
| `Scripts/build-app.sh` | 构建应用和分享扩展，生成 `dist/微信记录.app`。 |
| `Scripts/install.sh` | 安装现有构建，注册并启用分享扩展。 |
| `Scripts/verify.sh` | 运行测试，检查发布构建、签名、沙盒权限和分享扩展注册状态。 |
| `Scripts/test-share.sh` | 通过系统分享服务执行端到端测试，并逐字节比较源文件与落盘文件。 |
| `Scripts/make-dmg.sh` | 构建 DMG 和 SHA-256 校验文件。 |

`Scripts/test-share.sh` 要求分享扩展已安装并启用。测试会向 `~/Downloads/聊天存档/` 写入一个 ZIP，并校验文件内容。

## 项目结构

```text
Sources/
  ChatArchiveApp/     SwiftUI 主窗口与存档列表
  ChatArchiveCore/    文件名处理、原子保存与目录读取
  ChatArchiveShare/   macOS 分享扩展
Resources/            Info.plist、沙盒权限与图标
Scripts/              构建、安装、测试与打包脚本
Tests/                核心逻辑单元测试
```

`ChatArchiveCore` 只依赖 Foundation。主应用和分享扩展共用这套命名、去重和保存逻辑，接口层不重复实现文件处理。

## 隐私与权限

- 分享扩展只接收用户主动交给系统的文件。
- 沙盒权限仅包含 `com.apple.security.files.downloads.read-write`，没有网络权限。
- 应用不读取微信数据目录，不申请辅助功能、屏幕录制或完全磁盘访问权限。
- 删除操作会将文件移到系统废纸篓，存档始终保存在本机。

## 已知限制

- 当前只实现 macOS 版。Windows 方案见 [`docs/windows.md`](docs/windows.md)，尚未编译或验证。
- ad-hoc 签名适合本地使用，不适合直接公开分发。公开分发前需要配置 Developer ID 签名和公证流程。
- 应用不能自动操作用户的微信界面。每次转发都需要用户在微信和系统分享面板中确认。

## 文档

- [`docs/research.md`](docs/research.md)：微信分享机制、系统接口和公开实现调研。
- [`docs/windows.md`](docs/windows.md)：Windows Share Target 实现方案与验证清单。
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)：Lucide 图标许可与来源。

本项目与腾讯无关联。

## 贡献

提交变更前运行 `Scripts/verify.sh`。测试和示例必须使用合成数据，不要提交真实聊天记录、姓名、邮箱或本机路径。报告问题时请附上 macOS 版本、微信版本和复现步骤。

## 许可证

本项目原创代码采用 MIT License，见 [`LICENSE`](LICENSE)。`Resources/Icons` 中的 Lucide 图标仍按 ISC License 分发，详见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

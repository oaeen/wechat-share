# 微信记录

在微信里多选聊天记录，合并转发到“其他应用”，点击 **微信记录**，原始聊天 ZIP 会自动写入：

```text
~/Downloads/聊天存档/
```

当前仓库交付的是 **macOS 版**，已经在本机完成构建、安装和系统分享扩展注册。应用不读取微信数据库，不注入微信，也不上传文件；它只接收微信主动交给系统的分享文件。

应用名和系统分享入口都显示为 **微信记录**；保存目录保持为 `下载/聊天存档`。

## 平台说明

你提供的截图是 **macOS 分享面板**：菜单里的 AirDrop、Mail、Messages、Notes 都来自 macOS，不是 Windows 分享面板。

- macOS：微信通过 `com.apple.share-services` 分享扩展递送合并转发的 ZIP。本项目使用这个接口。
- Windows：微信没有公开转发 API，实际入口是 MSIX 的 `windows.shareTarget` 契约。调研结果、清单写法和落盘流程见 [`docs/windows.md`](docs/windows.md)。

这次没有把未在 Windows 上编译验证的代码混进交付物。当前这台机器是 macOS，能真实验证并注册的是截图所示的 macOS 入口。

## 已经实现

- 微信合并转发的 ZIP 自动保存到 `~/Downloads/聊天存档`。
- 保留原始文件名；遇到 `聊天记录.zip` 这类通用名时，自动加时间戳。
- 同名文件不覆盖，自动追加 `-2`、`-3`。
- 先写隐藏的 `.part` 临时文件，再原子移动到最终文件，避免留下半个压缩包。
- 支持一次分享多个文件。
- 每行悬停时提供转发、复制完整路径、在访达中显示和移到废纸篓四个图标；所有图标统一使用 Lucide。
- 删除会移到系统废纸篓，可以恢复。
- 界面采用沉浸式无标题栏，没有分割线；空状态是聊天气泡、简短文案和循环变化的颜文字。
- 打开下载文件夹放在菜单栏“文件 → 打开下载文件夹”（`⌘O`），不再占用窗口里的按钮。
- 分享扩展采用最小权限：只声明 App Sandbox 和“下载”文件夹读写，没有网络权限。

## 图标

应用图标和界面图标来自 [Lucide Static 1.80.0](https://unpkg.com/lucide-static@1.80.0/)，使用 ISC 许可证。App 图标使用 `message-square-share`，同时表达聊天记录和转发。图标文件在 `Resources/Icons`，许可证和第三方声明见 `Resources/Licenses/Lucide-ISC.txt` 与 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

## 使用

已安装时直接继续：

1. 完全退出微信，再重新打开。微信会缓存系统分享入口。
2. 在微信中多选消息，选择“合并转发”或“转发到其他应用”。
3. 在其他应用列表中点击 **微信记录**。
4. 文件会出现在 `~/Downloads/聊天存档`，也会显示在“微信记录”应用里。

首次打开应用读取历史、首次保存时，macOS 可能分别请求访问“下载”文件夹的权限，选择 **允许**。这个权限只用于写入和列出“下载/聊天存档”里的文件。

本地 ad-hoc 构建在重新签名替换后可能再次触发这个系统授权，重新允许即可。

重新构建和安装：

```bash
swift test
Scripts/build-app.sh
Scripts/install.sh
```

`Scripts/install.sh` 会安装到 `~/Applications/微信记录.app`，注册并启用分享扩展，然后打开应用。默认不需要管理员权限。

开发版默认放在用户目录，避免安装时请求管理员权限；DMG 内的 `Applications` 链接指向 `/Applications`，拖入后是系统级安装。需要把开发版直接装到系统目录时，可以运行：

```bash
INSTALL_DIR=/Applications Scripts/install.sh
```

打包 DMG：

```bash
Scripts/make-dmg.sh
```

输出在 `dist/微信记录-<版本>.dmg`，并生成对应的 `.sha256` 校验文件。安装包使用本地 ad-hoc 签名，未做 Apple Developer ID 签名和公证。

## 验证

本机实际执行结果：

```text
swift test
11 tests, 0 failures

Scripts/install.sh
分享扩展已注册，pluginkit 状态为启用

Scripts/test-share.sh
shared
端到端分享通过：~/Downloads/聊天存档/<测试文件>.zip
```

`Scripts/test-share.sh` 会通过系统 `NSSharingService` 调用“微信记录”，再逐字节比较源文件和落盘文件。它验证了真实分享扩展启动、沙盒下载权限和文件内容，但不会替你操作微信。

## 架构

```text
WeChat
  └── macOS Share Extension (ChatArchiveShare)
        ├── NSItemProvider → 临时文件
        └── ChatArchiveCore
              ├── 文件名清洗与去重
              ├── .part + 原子移动
              └── ~/Downloads/聊天存档

ChatArchiveApp（微信记录）
  └── 扫描同一目录，展示最近存档与注册状态
```

| 路径 | 职责 |
|---|---|
| `Sources/ChatArchiveCore` | 与 UI、AppKit 分享上下文解耦的命名、落盘和目录读取逻辑 |
| `Sources/ChatArchiveShare` | `com.apple.share-services` 扩展入口，负责接收 `NSItemProvider` |
| `Sources/ChatArchiveApp` | SwiftUI 主窗口与最近存档列表 |
| `Resources` | 应用与扩展的 Info.plist、沙盒权限 |
| `Scripts` | 图标生成、构建、签名、安装、注册和端到端分享测试 |

核心逻辑是平台无关的 Swift 代码。后续要加“解压为文件夹”“按聊天名建子目录”“保留最近 N 天”等功能，主要改 `ChatArchiveCore`，分享入口不需要重写。

## 开发与排错

```bash
swift test
CONFIG=release Scripts/build-app.sh
Scripts/verify.sh
Scripts/test-share.sh
```

如果微信菜单里没有 **微信记录**：

1. 确认应用在 `~/Applications/微信记录.app`，运行 `pluginkit -m -p com.apple.share-services | grep dev.chatarchive.app.share`。
2. 完全退出微信再打开。只关闭窗口不足以刷新分享菜单缓存。
3. 打开“系统设置 → 通用 → 登录项与扩展 → 共享”，确认“微信记录”已启用。

这个构建使用本地 ad-hoc 签名，适合当前机器直接使用；没有 Apple Developer ID 签名和公证，不适合直接公开分发。正式分发需要替换 `Scripts/build-app.sh` 里的签名身份并补公证步骤。

## 微信与系统接口结论

微信没有公开的“聊天记录转发 API”。两条链路都是操作系统提供的分享契约：

| 平台 | 微信侧行为 | 接收方注册方式 | 接收 API |
|---|---|---|---|
| macOS | 合并转发生成 ZIP，通过系统分享面板递送 | App 内嵌 `com.apple.share-services` 扩展 | `NSExtensionContext.inputItems` → `NSItemProvider` |
| Windows | 合并转发生成 ZIP，通过 Windows 分享面板递送 | MSIX 声明 `windows.shareTarget` | `IShareTargetActivatedEventArgs.ShareOperation.Data.GetStorageItemsAsync()` |

完整证据、开源实现和 Windows 实测约束见 [`docs/research.md`](docs/research.md) 与 [`docs/windows.md`](docs/windows.md)。

## 隐私

- 只处理用户主动分享给“微信记录”的文件。
- 不读取 `WeChat` 数据目录，不解密数据库，不注入进程。
- 分享扩展没有网络权限，也不申请辅助功能或屏幕录制权限。
- 文件仅保存在本机下载目录。

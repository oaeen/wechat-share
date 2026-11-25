# 微信聊天记录转发接口调研

## 摘要

截至当前调研，微信没有公开的聊天记录转发 API。合并转发时，微信把聊天记录打包为 ZIP，再交给操作系统的分享机制。接收方需要注册为系统分享目标，不能调用微信私有接口。

| 平台 | 分享目标 | 接收接口 |
| --- | --- | --- |
| macOS | `com.apple.share-services` 扩展 | `NSExtensionContext` 与 `NSItemProvider` |
| Windows | MSIX `windows.shareTarget` | `IShareTargetActivatedEventArgs` 与 `ShareOperation` |

本仓库实现 macOS 版。Windows 版只有设计文档，见 [`windows.md`](windows.md)。

## macOS 分享扩展

在微信 macOS 4.1.13 上，合并转发会生成一个 ZIP，内容可包含文本、图片和视频。微信通过系统分享面板把 ZIP 交给接收应用。

接收端位于应用包的 `Contents/PlugIns` 目录，是一个 `.appex` 扩展：

1. `Info.plist` 声明 `NSExtensionPointIdentifier = com.apple.share-services`。
2. 微信把分享内容放入 `NSExtensionContext.inputItems`。
3. 扩展遍历 `NSExtensionItem.attachments`，取得 `NSItemProvider`。
4. `NSItemProvider.loadFileRepresentation(forTypeIdentifier:)` 提供临时文件 URL。该文件会在回调结束后删除，扩展必须在回调内复制文件。
5. 分享面板中的名称来自扩展的 `CFBundleDisplayName`，图标来自宿主应用。

当前扩展声明最多接收 32 个文件。实现位于 `Sources/ChatArchiveShare`，文件保存和命名逻辑位于 `Sources/ChatArchiveCore`。

参考：

- [App Extension Programming Guide: Share](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html)
- [`NSExtensionContext`](https://developer.apple.com/documentation/foundation/nsextensioncontext)
- [`NSItemProvider`](https://developer.apple.com/documentation/foundation/nsitemprovider)

## Windows 分享目标

Windows 微信 4.x 使用 Windows Share Target 契约。接收应用需要 MSIX 包身份，并在应用清单中声明 `windows.shareTarget`。微信启动目标应用后，应用从激活参数中读取分享数据：

```csharp
using Windows.ApplicationModel;
using Windows.ApplicationModel.Activation;
using Windows.ApplicationModel.DataTransfer;

var activated = AppInstance.GetActivatedEventArgs();
var share = (IShareTargetActivatedEventArgs)activated;
var items = await share.ShareOperation.Data.GetStorageItemsAsync();
```

每个分享项通常是 `StorageFile`。源文件可能是临时文件，接收方必须在本次激活结束前完成复制。

公开实现还记录了几条没有官方文档支持的微信侧约束：

- 分享目标显示名包含连续的 `微信`、`WeChat` 或 `Weixin` 时，微信会隐藏该目标。
- 只声明 `.zip` 且只有一个 `DataFormat` 时，微信枚举阶段可能丢弃该目标。
- 修改注册信息后，需要结束 `Weixin` 和 `WeChatAppEx` 进程，再重新打开微信。

这些约束来自实测，不能视为稳定的微信 API 契约。Windows 清单和验证步骤见 [`windows.md`](windows.md)。

参考：

- [Share target manifest](https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-uap-sharetarget)
- [Receive shared data](https://learn.microsoft.com/en-us/windows/apps/develop/windows-integration/integrate-sharesheet-receive)
- [`ShareOperation`](https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.datatransfer.sharetarget.shareoperation)
- [ChatPCBridge](https://github.com/bwjoke/ChatPCBridge)
- [WeChatBridge](https://github.com/freestylefly/WeChatBridge)
- [dsh-wechat-share](https://github.com/Tuiltex-0216/dsh-wechat-share)

## 证据范围

macOS 实现已经通过 `Scripts/test-share.sh` 验证。测试使用系统 `NSSharingService` 启动扩展，并逐字节比较源文件与下载目录中的结果。

Windows 行为来自微软文档、公开实现的说明和其排障记录。仓库没有 Windows 构建产物，也没有在 Windows 微信上执行端到端验证。正式实现前需要在 Windows 上完成注册、签名、沙盒和文件一致性测试。

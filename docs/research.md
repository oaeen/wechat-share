# 调研：微信聊天记录转发到“其他应用”

## 结论

微信没有公开的聊天记录转发 API。微信只是把合并转发的内容交给操作系统的分享机制：

- macOS 微信 4.1.13 起，合并转发会生成包含 TXT、图片和视频的 ZIP，并通过 `NSSharingServicePicker` 展示系统分享目标。接收方必须是一个 `com.apple.share-services` 扩展。
- Windows 微信 4.x 通过 Windows 的 `windows.shareTarget` 契约枚举第三方应用。目标应用需要 MSIX 包身份，在清单中声明 Share Target，接收 `StorageItems`，再用 WinRT 读取微信交给系统的文件。

因此，项目真正依赖的是操作系统的公开扩展机制，不是微信私有接口，也不涉及读取微信数据库或注入微信进程。

## macOS 链路

接收端由应用包内的 `.appex` 提供。

1. 扩展 `Info.plist` 声明 `NSExtensionPointIdentifier = com.apple.share-services`。
2. 微信把合并转发结果作为文件交给 `NSExtensionContext.inputItems`。
3. 扩展遍历 `NSExtensionItem.attachments`，得到 `NSItemProvider`。
4. 用 `loadFileRepresentation(forTypeIdentifier:)` 读取文件。临时文件在回调闭包返回后会被系统删除，所以复制必须发生在回调内部。
5. 系统分享面板中的显示名来自扩展的 `CFBundleDisplayName`，图标来自宿主应用。

macOS 版的应用名和系统分享入口都显示为 **微信记录**。

Windows 分享目标的显示名不能直接复用这个名称，原因见下文的微信枚举过滤规则。

参考：

- Apple App Extension Programming Guide: <https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html>
- `NSExtensionContext`: <https://developer.apple.com/documentation/foundation/nsextensioncontext>
- `NSItemProvider`: <https://developer.apple.com/documentation/foundation/nsitemprovider>

## Windows 链路

微信 Windows 不在进程间调用自定义 API，而是使用 Windows 的 Share Target 契约。对实现方来说，核心类型是：

```csharp
var activated = AppInstance.GetActivatedEventArgs();
var share = (IShareTargetActivatedEventArgs)activated;
var items = await share.ShareOperation.Data.GetStorageItemsAsync();
```

每个分享项通常是一个 `StorageFile`。微信的合并转发产物是 ZIP；接收方应在报告完成前复制文件内容，因为分享宿主提供的文件可能是临时文件。

参考：

- Share Target 清单元素：<https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-uap-sharetarget>
- 接收分享数据：<https://learn.microsoft.com/en-us/windows/apps/develop/windows-integration/integrate-sharesheet-receive>
- `ShareOperation`：<https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.datatransfer.sharetarget.shareoperation>

### 微信侧的非官方约束

以下行为来自能正常在微信菜单中显示的公开实现与其实测记录，不是腾讯官方文档：

- `DisplayName` 含连续的 `微信`、`WeChat` 或 `Weixin` 子串时，微信会隐藏该分享目标。
- 只声明 `.zip` 且只声明一个 `DataFormat` 时，微信枚举阶段会丢掉该目标；腾讯自己的可显示包使用 `SupportsAnyFileType` 加 `StorageItems`、`Text`、`URI`、`Bitmap`。
- 分享目标运行时可能是 `mediumIL`，不能直接启动任意外部进程。落盘应由分享目标自己完成，需要主界面时另设 full-trust 宿主。
- 改完注册信息后，微信的 `WeChatAppEx` 菜单缓存不会立即刷新；要结束微信相关进程再重新打开。

相关开源实现：

- ChatPCBridge：<https://github.com/bwjoke/ChatPCBridge>
- 微信流 WeChatBridge：<https://github.com/freestylefly/WeChatBridge>
- dsh-wechat-share：<https://github.com/Tuiltex-0216/dsh-wechat-share>

## 为什么当前交付 macOS 版

任务提供的截图是 macOS 分享面板，开发机也是 macOS。此时可以完成真实的系统注册、扩展启动和沙盒落盘测试；Windows 版则需要 Windows 机器、MSIX 签名工具和微信客户端做同样级别的验证。

在没有 Windows 验证环境的情况下直接提交 Windows 可执行代码，会把清单过滤、包身份、签名和沙盒问题留给用户试错，不符合“完成并验证”的标准。因此当前仓库先交付可实机使用的 macOS 版，并把 Windows 的接口、清单形态和实现约束单独记录在 [`windows.md`](windows.md)。

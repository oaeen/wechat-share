# Windows 实现方案

本文件是 Windows 版的实现规格与验证清单，不是已在 Windows 上编译的产物。

macOS 版当前显示为“微信记录”。由于微信 Windows 会过滤含连续 `微信` / `WeChat` / `Weixin` 的分享目标显示名，下面的 Windows 清单暂用“聊天存档”作为显示名。

## 目标行为

```text
微信多选消息
  → 合并转发
  → 其他应用
  → 聊天存档
  → 原始 ZIP 自动保存到 %USERPROFILE%\Downloads\聊天存档
```

微信不会调用第三方私有接口，接收端需要注册为 Windows Share Target。

## 技术栈

- .NET 8 或 .NET 10
- `net8.0-windows10.0.19041.0`
- C# / WinRT 投影（`Microsoft.Windows.CsWinRT`）
- MSIX 稀疏包或完整包
- 可选 WPF / WinUI 主窗口

分享目标本身应保持无窗口、快速结束。设置、历史列表和“打开下载目录”放在主程序里；分享目标只负责接收、复制、报告完成。

## MSIX 清单

核心声明如下：

```xml
<Identity
  Name="ChatArchive.ShareTarget"
  Publisher="CN=ChatArchive Local Development"
  Version="0.1.0.0"
  ProcessorArchitecture="neutral" />

<Properties>
  <DisplayName>聊天存档</DisplayName>
  <PublisherDisplayName>ChatArchive</PublisherDisplayName>
  <Logo>Assets\Square150x150Logo.png</Logo>
  <uap10:AllowExternalContent>true</uap10:AllowExternalContent>
</Properties>

<Capabilities>
  <rescap:Capability Name="runFullTrust" />
  <rescap:Capability Name="unvirtualizedResources" />
</Capabilities>

<Application
  Id="Share.Hub"
  Executable="share-target\ChatArchive.ShareTarget.exe"
  uap10:TrustLevel="mediumIL"
  uap10:RuntimeBehavior="win32App">
  <uap:VisualElements
    AppListEntry="none"
    DisplayName="聊天存档"
    Description="保存微信合并转发的聊天记录"
    BackgroundColor="transparent"
    Square44x44Logo="Assets\Square44x44Logo.png"
    Square150x150Logo="Assets\Square150x150Logo.png" />
  <Extensions>
    <uap:Extension Category="windows.shareTarget">
      <uap:ShareTarget Description="聊天存档">
        <uap:SupportedFileTypes>
          <uap:SupportsAnyFileType />
        </uap:SupportedFileTypes>
        <uap:DataFormat>StorageItems</uap:DataFormat>
        <uap:DataFormat>Text</uap:DataFormat>
        <uap:DataFormat>URI</uap:DataFormat>
        <uap:DataFormat>Bitmap</uap:DataFormat>
      </uap:ShareTarget>
    </uap:Extension>
  </Extensions>
</Application>
```

`SupportsAnyFileType` 看起来比 `.zip` 宽，但这是微信菜单枚举的兼容要求。运行时仍然只处理 ZIP 或其他明确允许的文件类型，不能把宽声明当成放宽业务校验。

## 激活与保存

入口程序应使用系统 Inbox WinRT API，不要依赖 Windows App SDK 的 `Microsoft.Windows.AppLifecycle.AppInstance`；稀疏包引入 Windows App SDK 时容易在激活阶段出现 `REGDB_E_CLASSNOTREG`。

```csharp
using Windows.ApplicationModel;
using Windows.ApplicationModel.Activation;
using Windows.ApplicationModel.DataTransfer;

var activated = AppInstance.GetActivatedEventArgs();
if (activated is not IShareTargetActivatedEventArgs share)
{
    return;
}

var operation = share.ShareOperation;
operation.ReportStarted();

if (!operation.Data.Contains(StandardDataFormats.StorageItems))
{
    operation.ReportError("只接收文件型分享。");
    return;
}

var items = await operation.Data.GetStorageItemsAsync();
foreach (var item in items)
{
    if (item is not StorageFile file || string.IsNullOrWhiteSpace(file.Path))
    {
        operation.ReportError("分享项不是可读取的文件。");
        return;
    }

    // 必须在本次激活结束前读取内容；源文件可能是临时文件。
}

operation.ReportDataRetrieved();
operation.ReportCompleted();
```

保存路径：

```csharp
var downloads = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
    "Downloads",
    "聊天存档");
Directory.CreateDirectory(downloads);
```

逐文件复制时使用相同的原子落盘策略：

1. 在目标目录写 `.chatarchive-<uuid>.part`。
2. 文件名清洗、去重。
3. 写完后再移动到最终文件名。
4. 失败时删除临时文件，不影响已存在的存档。

## 显示名与文件名

微软和腾讯都没有公开“微信分享菜单过滤”的完整规则。根据开源项目的实测：

```text
显示名包含连续的 微信 / WeChat / Weixin → 微信菜单隐藏
只声明 .zip 且只有一个 DataFormat → 微信枚举阶段丢弃
```

因此：

- 分享入口使用 **聊天存档**，不带微信品牌词。
- `SupportedFileTypes` 使用 `SupportsAnyFileType`。
- `DataFormat` 同时声明 `StorageItems`、`Text`、`URI`、`Bitmap`。
- 运行时再校验实际收到的内容。

这些规则不是官方 API 契约，微信版本升级后必须重新实机验证。可参考 ChatPCBridge 的实现和 WeChatBridge 的 Windows 排障记录：

- <https://github.com/bwjoke/ChatPCBridge>
- <https://github.com/freestylefly/WeChatBridge>
- <https://github.com/Tuiltex-0216/dsh-wechat-share>

## 安装与签名

开发机需要：

1. Windows 10 19041 或更新版本。
2. Windows SDK 的 `MakeAppx.exe`、`signtool.exe`。
3. 已安装 .NET SDK。
4. 一个受本机信任的开发证书，或正式代码签名证书。

流程：

1. `dotnet publish` 生成 share target 可执行文件。
2. 生成或更新 `AppxManifest.xml` 和图标资源。
3. `MakeAppx pack` 打包 MSIX。
4. `signtool sign` 签名。
5. 信任开发证书。
6. `Add-AppxPackage -ExternalLocation <install-root>` 注册稀疏包。
7. 结束全部 `Weixin` / `WeChatAppEx` 进程，重新打开微信。
8. 在微信的“转发到其他应用”中确认 **聊天存档** 出现。

系统文件资源管理器右键分享里能看到目标，只能证明系统注册成功；微信菜单有自己的枚举缓存和过滤规则，两者必须分别验证。

## 验证清单

- [ ] `Get-AppxPackage` 能查到分享目标包。
- [ ] `ShareTarget.exe --registration-check` 能打印 package identity 和 AUMID。
- [ ] 资源管理器右键分享能看到“聊天存档”。
- [ ] 微信重启后，“其他应用”能看到“聊天存档”。
- [ ] 分享合成 ZIP 后，目标目录出现字节一致的文件。
- [ ] 同名 ZIP 保存两次不覆盖。
- [ ] 通用文件名会追加时间戳。
- [ ] 微信关闭期间分享不会留下无法解释的错误。
- [ ] 卸载 MSIX 后，分享入口消失，下载目录中的存档不被删除。

## 当前状态

Windows 版尚未在 Windows 实机上编译、安装和通过真实微信分享验证。macOS 版已完成同等链路中的注册、系统分享扩展启动、沙盒落盘和字节一致性验证。

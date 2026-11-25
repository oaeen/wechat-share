# Windows Share Target 实现方案

状态：设计稿，尚未在 Windows 上编译或发布。

本文给出 Windows 版的实现范围、关键接口和验证条件。macOS 版的实现与验证结果见仓库 [README](../README.md)。

## 目标流程

```text
微信多选消息
  → 合并转发
  → 其他应用
  → 聊天存档
  → %USERPROFILE%\Downloads\聊天存档
```

微信 Windows 会过滤含连续 `微信`、`WeChat` 或 `Weixin` 的分享目标显示名，因此 Windows 版暂用“聊天存档”作为入口名称。

## 运行环境

- Windows 10 版本 2004（内部版本 19041）或更新版本。
- .NET 10 LTS 或更新版本。
- Windows SDK，包含 `MakeAppx.exe` 和 `signtool.exe`。
- MSIX 包身份和受本机信任的开发证书，或正式代码签名证书。

## 技术选型

- 使用 C# 和 .NET 的 WinRT 投影读取分享数据。
- 使用 MSIX 完整包，或以稀疏包提供包身份。
- 分享目标保持无窗口，收到文件后立即保存并结束。
- 主窗口独立于分享目标，负责历史列表、设置和打开下载目录。

分享目标以 `mediumIL` 运行。它不能启动任意外部进程，文件保存应在分享目标内部完成。

## 注册分享目标

清单的关键声明如下。片段省略了 XML 命名空间声明。

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

`SupportsAnyFileType` 是为兼容微信枚举而使用的宽声明。运行时仍需检查文件类型，只保存允许的文件。

清单中的 `Publisher` 必须与签名证书主体一致，否则 MSIX 安装或注册会失败。

## 接收分享

使用系统 WinRT API 读取激活参数。不要使用 Windows App SDK 的 `Microsoft.Windows.AppLifecycle.AppInstance`，稀疏包在激活阶段可能返回 `REGDB_E_CLASSNOTREG`。

```csharp
using Windows.ApplicationModel;
using Windows.ApplicationModel.Activation;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;

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

    // 必须在本次激活结束前复制文件，源路径可能是临时文件。
}

operation.ReportDataRetrieved();
operation.ReportCompleted();
```

生产实现还需要捕获异常，并在失败时调用 `ReportError`。

## 保存文件

目标目录：

```csharp
var downloads = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
    "Downloads",
    "聊天存档");
Directory.CreateDirectory(downloads);
```

保存流程应与 macOS 版保持一致：

1. 校验源文件存在且不是目录。
2. 清洗文件名，通用名称追加时间戳。
3. 在目标目录写入 `.chatarchive-<id>.part`。
4. 复制完成后移动到最终文件名。
5. 遇到同名文件时追加 `-2`、`-3`，不覆盖已有存档。
6. 任一步失败时删除临时文件。

## 微信兼容性

以下规则来自公开实现和实测记录，不是腾讯或微软的稳定契约：

- 显示名包含连续的 `微信`、`WeChat` 或 `Weixin` 时，微信会隐藏目标。
- 只声明 `.zip` 且只有一个 `DataFormat` 时，微信可能不显示目标。
- `SupportsAnyFileType` 配合 `StorageItems`、`Text`、`URI`、`Bitmap` 可以出现在微信菜单中。
- 微信会缓存分享目标列表。更新注册后，结束 `Weixin` 和 `WeChatAppEx` 进程，再重新打开微信。

实现和发布前应重新测试当前微信版本，不要把这些规则当作长期接口保证。

参考实现：

- [ChatPCBridge](https://github.com/bwjoke/ChatPCBridge)
- [WeChatBridge](https://github.com/freestylefly/WeChatBridge)
- [dsh-wechat-share](https://github.com/Tuiltex-0216/dsh-wechat-share)

## 构建与安装

1. `dotnet publish` 生成分享目标可执行文件。
2. 生成 `AppxManifest.xml` 和图标资源。
3. 使用 `MakeAppx pack` 生成 MSIX。
4. 使用 `signtool sign` 签名。
5. 在开发机信任签名证书。
6. 使用 `Add-AppxPackage` 安装完整包，或用 `-ExternalLocation` 注册稀疏包。
7. 结束微信进程并重新打开。
8. 在微信“转发到其他应用”中确认“聊天存档”出现。

资源管理器右键菜单中出现目标，只能说明 Windows 已注册分享目标。微信有独立的枚举和过滤逻辑，必须在微信内单独验证。

## 验证清单

- [ ] `Get-AppxPackage` 能查到分享目标包。
- [ ] 分享目标能输出 package identity 和 AUMID。
- [ ] Windows 资源管理器分享菜单显示“聊天存档”。
- [ ] 微信“其他应用”菜单显示“聊天存档”。
- [ ] 分享 ZIP 后，目标目录出现字节一致的文件。
- [ ] 同一 ZIP 保存两次不会覆盖。
- [ ] 通用文件名会追加时间戳。
- [ ] 分享临时文件在激活结束后不再被引用。
- [ ] 卸载 MSIX 后分享入口消失，已有存档不被删除。

当前仓库没有 Windows 工程和构建产物。上述清单需要在 Windows 实机上逐项验证后，才能将 Windows 版标记为可用。

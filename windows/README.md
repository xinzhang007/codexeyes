# Windows 版本

Windows 版本使用原生 WPF 和 .NET 8，不依赖浏览器或 Electron。它会在桌面右上角显示置顶卡片，读取 Codex CLI 在当前 Windows 用户目录中保存的记录。

## 使用前提

- Windows 10 或 Windows 11
- .NET 8 SDK（构建时需要；发布后的单文件应用运行时不需要单独安装 .NET）
- 已安装并登录 [Codex CLI](https://github.com/openai/codex)

Codex CLI 的数据目录为：

```text
%USERPROFILE%\\.codex\\auth.json
%USERPROFILE%\\.codex\\sessions\\**\\*.jsonl
```

## 构建和安装

在 PowerShell 中，从仓库根目录运行：

```powershell
.\windows\install.ps1
```

脚本会发布自包含的 `win-x64` 单文件程序，放在 `windows/publish/`，创建 Windows 启动文件夹快捷方式，然后启动组件。桌面不会创建快捷方式。

ARM64 Windows 设备：

```powershell
.\windows\install.ps1 -Runtime win-arm64
```

只想重新构建：

```powershell
.\windows\build.ps1
```

卸载并取消开机启动：

```powershell
.\windows\uninstall.ps1
```

## Windows 上的行为

窗口始终置顶、隐藏任务栏图标、无关闭按钮；拖动卡片可改变位置，位置保存在当前 Windows 用户的注册表中。用量文件发生变化时立即读取，每 30 秒进行一次兜底刷新。点击用量区域会复制摘要。

Windows 虚拟桌面由系统管理；切换虚拟桌面后，组件会跟随当前桌面显示。

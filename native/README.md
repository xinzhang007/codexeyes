# 原生 macOS 桌面组件

`Sources/CodexEyesApp.swift` 是 SwiftUI/AppKit 原生实现。它会创建一个固定尺寸、可拖动、记住位置的桌面面板，并注册一个菜单栏入口。组件会加入所有 Spaces，使用桌面层级与其他插件共存，不依赖浏览器或 WebView。

用量来自本机 Codex CLI 的 `~/.codex/sessions/**/*.jsonl`，账号姓名和邮箱来自 `~/.codex/auth.json`。面板显示的是当前登录账号的真实周期数据，不使用演示数值。

组件监听日志文件变化并在变化后立即刷新，每 30 秒进行一次兜底检查；macOS 会话锁定时暂停高频读取。

悬停用量区域会显示隐藏的窗口详情，点击用量区域可复制当前摘要；头像地址不可用时使用账号缩写作为回退。

构建：

```bash
./build.sh
```

构建产物位于 `app/codexeyes.app`。

安装到系统“应用程序”文件夹，并设置登录后自动显示：

```bash
./install.sh
```

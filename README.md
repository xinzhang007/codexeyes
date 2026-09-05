# codexeyes

> 一个原生 macOS 桌面小组件，让你不用打开 Codex 或浏览器，就能看到当前 Codex 用量。

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111827?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/license-MIT-6A5AF9.svg)](LICENSE)
[![Native SwiftUI](https://img.shields.io/badge/native-SwiftUI%20%2B%20AppKit-0f766e.svg)](native/)

![codexeyes 桌面组件演示（示例数据）](demo/codexeyes-demo.svg)

演示图中的账号、百分比和 Token 数字都是虚构的，只用于展示布局。真实运行时，组件只显示你本机 Codex 账号的数据。

## 这是什么

codexeyes 是一个原生 macOS 桌面组件。它固定显示在桌面右上角，与其他桌面小组件一起工作：

- 显示当前登录的 Codex 账号、头像和套餐类型
- 显示本周期已使用额度、剩余时间和生成/上下文 Token
- Codex 日志变化时立即更新，每 30 秒做一次兜底检查
- 支持所有桌面空间，拖动后会记住位置
- 文字使用白色，背景为半透明深色卡片，不依赖浏览器或 WebView

适合经常使用 Codex CLI、希望随时掌握额度的开发者，也适合想要一个安静、低打扰桌面状态卡片的人。

## 安装

### 普通用户：一条命令安装

先确认已经安装并登录 [Codex CLI](https://github.com/openai/codex)，然后在终端执行：

```bash
git clone https://github.com/xinzhang007/codexeyes.git
cd codexeyes
./native/install.sh
```

安装脚本会把应用放入 `/Applications/codexeyes.app`，并设置为登录 macOS 后自动显示。桌面上不会额外出现应用图标。

如果 macOS 提示应用来自未验证的开发者，请在“应用程序”文件夹中右键点击 `codexeyes`，选择“打开”。本项目没有使用 Apple Developer 签名。

### 需要重新构建时

现成的应用包适合 Apple Silicon Mac。Intel Mac，或希望从当前源码重新编译时，执行：

```bash
./native/build.sh
./native/install.sh
```

需要 macOS 13 或更高版本，以及 Xcode Command Line Tools（提供 `swiftc`）。

## 第一次打开后看不到数据？

codexeyes 不生成或猜测用量，它读取 Codex CLI 已经写入本机的记录。请按下面顺序检查：

1. 在终端运行一次 `codex`，确认已经登录并完成一次请求。
2. 确认本机存在 `~/.codex/auth.json` 和 `~/.codex/sessions/`。
3. 重新打开 `/Applications/codexeyes.app`。

如果仍显示“等待 Codex 数据”，通常表示 Codex CLI 尚未写入可用的额度记录。

## 如何使用

- 将鼠标悬停在用量区域，可查看当前额度窗口的补充信息。
- 点击用量区域，可复制一行简短摘要，方便粘贴到 issue 或团队聊天中。
- 拖动卡片可调整位置；位置会保存在本机。
- 不需要手动刷新。文件监听和 30 秒兜底计时器会自动更新。

## 隐私与安全

用量和账号信息只在本机读取，用于渲染桌面面板。应用不会把用量、账号姓名或邮箱上传到本项目或其他服务。若本机登录凭据提供头像地址，应用仅按该地址加载头像；用量数据本身不会通过网络发送。

仓库不包含登录凭据、会话日志、账号姓名、邮箱或本机路径。你可以在源码中查看读取逻辑：[CodexEyesApp.swift](native/Sources/CodexEyesApp.swift)。

## 面向开发者

项目结构很小，便于阅读和修改：

```text
app/                    已构建的 macOS 应用包
demo/                   不含真实账号信息的演示图
native/Sources/         SwiftUI/AppKit 源码
native/build.sh         本地构建脚本
native/install.sh       安装与登录启动脚本
manifest.json           桌面组件元数据
```

修改源码后运行：

```bash
./native/build.sh
./native/install.sh
```

欢迎提交 Issue 或 Pull Request。建议在提交前确认没有把 `~/.codex` 下的文件、截图或日志复制到仓库。

## 卸载

```bash
launchctl bootout "gui/$(id -u)/local.codex.eyes" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/local.codex.eyes.plist"
rm -rf /Applications/codexeyes.app
```

## 许可证

本项目使用 [MIT License](LICENSE)。

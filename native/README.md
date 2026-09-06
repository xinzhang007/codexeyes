# 原生 macOS 实现

这里是 codexeyes 的 SwiftUI/AppKit 实现。它创建一个固定尺寸、固定位置的桌面面板，并注册一个菜单栏入口。面板位于 macOS 桌面层，应用窗口会自然覆盖它。

## 数据来源

组件读取 Codex CLI 写入本机的：

- `~/.codex/sessions/**/*.jsonl`：额度和 Token 记录
- `~/.codex/auth.json`：登录账号、套餐和头像信息

组件不会生成演示数值。文件变化时立即刷新，每 30 秒进行一次兜底检查；macOS 会话锁定时暂停高频读取。

## 构建与安装

```bash
./build.sh
./install.sh
```

构建产物位于 `app/codexeyes.app`。`install.sh` 会安装到 `/Applications`，并通过 LaunchAgent 设置登录后自动显示。

演示图片位于 [`../demo/codexeyes-demo.svg`](../demo/codexeyes-demo.svg)，其中所有数据均为虚构内容。

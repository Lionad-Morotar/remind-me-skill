---
title: remind-me-skill
description: 创建系统提醒，支持 reminder / calendar / stickies / break 四种类型，跨 macOS / Windows / Linux。
---

# remind-me-skill

创建系统提醒，按场景分流到四种类型：

- `reminder`：写入系统「提醒事项」App，适合任务型、需勾选完成的待办。
- `calendar`：写入系统「日历」App，适合一次性、到点即过的未来事件。
- `stickies`：生成桌面便签，适合常驻展示的内容。
- `break`：后台定时弹窗强制打断，支持睡眠/锁屏唤醒后补提醒。

支持 macOS、Windows、Linux 三平台。

## 安装

```bash
npx skills add -g Lionad-Morotar/remind-me-skill
```

如果你的 IDE 不支持 Slash Command，可以在提示词前加前缀以确保触发：

```plaintext
使用 remind-me 技能，10 分钟后提醒我开会
```

## 使用

### 提醒事项（reminder）

适合需要勾选完成的任务。

```plaintext
/remind-me 提醒我下周三前提交报销单
```

### 日历事件（calendar）

适合一次性、到点即过的事件。

```plaintext
/remind-me 明天下午 3 点复盘 --type calendar
```

### 桌面便签（stickies）

适合常驻展示的内容。

```plaintext
/remind-me 便签：今日核心目标 --type stickies
```

### 强制打断（break）

适合必须被打断的场景，到点弹系统对话框。

```plaintext
/remind-me 25 分钟后提醒我休息 --type break
```

## 脚本工具

安装后脚本位于 `~/.claude/skills/remind-me/scripts/`，可手动管理在途任务：

```bash
# 列出在途任务
~/.claude/skills/remind-me/scripts/list_tasks.sh

# 取消指定任务
~/.claude/skills/remind-me/scripts/cancel_task.sh <PID>

# 清理过期任务（自动执行）
~/.claude/skills/remind-me/scripts/cleanup_expired.sh
```

## 项目结构

```
remind-me-skill/
└── skills/
    └── remind-me/
        ├── SKILL.md          # Skill 主入口与路由
        ├── references/       # 各类型详细参考
        ├── scripts/          # 跨平台脚本
        └── assets/           # 示例图片等资源
```

## 支持平台

- **macOS**：Reminders.app / Calendar.app / Stickies.app / osascript 弹窗 / LaunchAgent
- **Windows**：PowerShell / Windows Forms / Task Scheduler
- **Linux**：systemd user timer / zenity / kdialog

## 依赖

- macOS：osascript、launchctl
- Windows：PowerShell 5.0+
- Linux：systemd、zenity 或 kdialog

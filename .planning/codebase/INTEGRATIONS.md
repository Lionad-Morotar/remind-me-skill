# 外部集成

**分析日期：** 2026-07-13

## API 与外部服务

**外部 SaaS API:**
- 无。项目纯本地脚本，不调用任何远程 API、不发送网络请求

**本地系统 API（macOS）：**
- Reminders.app - 任务型提醒写入
  - 通道：`osascript` + AppleScript 对象模型（`make new reminder`）
  - 参考：`references/reminder-help.md`
- Calendar.app - 一次性事件写入
  - 通道：`osascript` + AppleScript（`make new event` + `display alarm`）
  - 参考：`references/calendar-help.md`
- Stickies.app - 桌面便签
  - 通道：无 AppleScript 对象模型，使用 `System Events` GUI 快捷键 + RTFD 剪贴板
  - 参考：`references/stickies-help.md`、`scripts/stickies_make_rtf.swift`
- System Events - GUI 自动化（菜单点击、键盘事件、窗口定位）
- `display dialog` / `display notification` - 强制弹窗与系统通知

**本地系统 API（Windows）：**
- Task Scheduler - 登录/解锁时触发过期提醒
- Windows Forms - 消息框 UI

**本地系统 API（Linux）：**
- systemd user units - 定时唤醒（`systemd/remind-me.timer` + `.service`）
- X11/Wayland 对话框工具 - `zenity` / `kdialog` / `notify-send`

## 数据存储

**数据库：**
- 无数据库
- 任务持久化：本地文件系统 `~/.config/remind-me-skill/tasks/<target_epoch>_<pid>.task`
  - 格式：纯文本 key=value（`TITLE` / `MESSAGE` / `CREATED_AT` / `TARGET_AT` / `PID` / `NOTIFIED`）
  - 参考：`scripts/create_reminder.sh:36-44`

**文件存储：**
- 本地文件系统
- 日志（macOS）：`/tmp/remind-me-skill.log`、`/tmp/remind-me-skill.error.log`
- 日志（Linux）：`journalctl --user -u remind-me.service`

**缓存：**
- 无缓存层

## 认证与身份

**认证提供方：**
- 无。全部依赖当前登录用户的本地权限
- LaunchAgent 使用 `gui/$(id -u)` 域加载（`install_agent.sh:59`）

## 监控与可观测性

**错误追踪：**
- 无外部服务
- 失败回退：AppleScript 失败时输出 stderr；Linux 无对话框工具时降级为 `echo` 到 stderr（`scripts/linux/dialog.sh:39-42`）

**日志：**
- macOS LaunchAgent stdout/stderr → `/tmp/remind-me-skill.log`、`/tmp/remind-me-skill.error.log`
- Linux systemd → journald
- 任务执行结果通过 stdout 返回 PID 给调用方

## CI/CD 与部署

**托管：**
- GitHub 仓库：`Lionad-Morotar/remind-me-skill`
- 分发渠道：`skills` CLI（`npx skills add -g <owner>/<repo>`）

**CI 流水线：**
- 无 CI 配置
- 版本管理：遵循 Semantic Versioning，`CHANGELOG.md` 采用 Keep a Changelog 格式

## 环境配置

**必需环境变量：**
- 无必需环境变量

**可选环境变量：**
- `DIALOG_TOOL` - Linux 对话框后端覆盖（`zenity` / `kdialog` / `notify-send` / `none`），默认自动探测（`scripts/linux/dialog.sh:5-15`）
- `HOME` - 定位 `~/.config/remind-me-skill/` 与 `~/Library/LaunchAgents/`

**机密位置：**
- 无 secrets。仓库不含任何凭据、token、密钥文件

## Webhook 与回调

**入向：**
- 无 HTTP 端点
- 系统级回调：
  - macOS：LaunchAgent `StartInterval=60` 周期触发 `wakeup_handler.sh`
  - Windows：Task Scheduler 登录/解锁事件
  - Linux：systemd timer `OnUnitActiveSec=60`

**出向：**
- 无网络回调
- 仅本地：任务文件创建/删除、AppleScript 调用、剪贴板写入

---

*集成审计：2026-07-13*

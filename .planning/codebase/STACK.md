# 技术栈

**分析日期：** 2026-07-13

## 语言

**主要：**
- Bash 4.0+ - 核心业务脚本（macOS/Linux 任务管理、唤醒处理、过期清理）
- AppleScript / osascript - macOS 原生 App 自动化（Reminders、Calendar、Stickies、System Events、display dialog）

**次要：**
- Swift 5.x - `scripts/stickies_make_rtf.swift` 富文本便签生成器（AppKit / NSAttributedString / RTFD）
- PowerShell 5.0+ - `scripts/windows/*.ps1` Windows 平台脚本
- XML / plist - `install_agent.sh` 动态生成 LaunchAgent 配置

## 运行时

**环境：**
- 无运行时容器，直接调用宿主操作系统原生工具
- Claude Code Skill 分发机制（`SKILL.md` frontmatter + `references/` 路由）

**包管理器：**
- 无 npm/pnpm/yarn
- 无 lockfile
- 安装命令：`npx skills add -g Lionad-Morotar/remind-me-skill`（通过 `skills` CLI 一次性拉取整个目录）

## 框架

**核心：**
- 无应用框架，纯脚本集合
- 核心抽象：Skill 路由（SKILL.md）→ 类型 reference（`references/<type>-help.md`）→ 平台脚本（`scripts/<platform>/`）

**测试：**
- 无自动化测试框架（项目为系统脚本，依赖实机验证）

**构建/开发：**
- 无构建步骤
- Swift 脚本通过 `swift <file>` 直译执行
- 验证手段：`bash -n <script>` 语法检查 + 实机 `osascript` / `powershell` 调用

## 关键依赖

**关键（macOS）：**
- `osascript` - AppleScript 解释器，所有 macOS 原生 App 调用与对话框入口（`README.md:104`）
- `date` - epoch 计算与相对时间偏移（`date -v+3m` 处理跨月）
- `launchctl` - LaunchAgent 加载（`install_agent.sh:59`）

**关键（Windows）：**
- PowerShell 5.0+ - 所有脚本载体
- Windows Forms - 消息框
- Task Scheduler - 过期提醒唤醒回调（任务名 `RemindMe-Skill-Wakeup`）

**关键（Linux）：**
- `systemd` - user timer 定期触发 wakeup_handler（`systemd/remind-me.timer`）
- `zenity`(GTK) 或 `kdialog`(KDE) - 对话框（`scripts/linux/dialog.sh` 自动探测）
- `notify-send` - 非交互式通知 fallback
- `coreutils` - `date` 等基础命令

**基础设施：**
- macOS 系统 App：Reminders.app、Calendar.app、Stickies.app、System Events
- macOS LaunchAgent：`~/Library/LaunchAgents/com.local-link.remind-me.plist`
- 任务存储：本地文件系统 `~/.config/remind-me-skill/tasks/`

## 配置

**环境：**
- 无环境变量，无 `.env` 文件
- 可选环境变量：`DIALOG_TOOL`（Linux 强制指定对话框后端，默认自动探测）
- 运行时数据目录：`$HOME/.config/remind-me-skill/tasks/`

**构建：**
- 无构建配置

**Skill 元配置：**
- `SKILL.md` frontmatter：`name`, `description`, `argument-hint`, `disable-model-invocation`

## 平台要求

**开发：**
- macOS 10.10+（依赖 osascript；AppleScript 对象模型在 10.10 起稳定）
- Bash 4.0+
- 可选：Swift toolchain（仅修改 `stickies_make_rtf.swift` 时需要）

**Production / 部署目标：**
- macOS：LaunchAgent（每 60 秒触发一次 wakeup 检查）
- Windows：Task Scheduler 登录/解锁触发
- Linux：systemd `--user` timer（`WantedBy=default.target`）
- 无需服务器，全部本地执行

## 开发命令

无构建系统，直接调用脚本：

```bash
# macOS 创建提醒
scripts/create_reminder.sh "<标题>" "<内容>" <epoch>

# 列出在途任务
scripts/list_tasks.sh
scripts/list_tasks.sh --expired

# 取消任务
scripts/cancel_task.sh <PID>

# 过期清理（自动由 LaunchAgent/systemd 调用）
scripts/cleanup_expired.sh

# 生成 Stickies 富文本
swift scripts/stickies_make_rtf.swift
```

## 部署流程

1. 终端用户执行 `npx skills add -g Lionad-Morotar/remind-me-skill`
2. 首次调用 `create_reminder.sh` 时自动安装平台调度器（LaunchAgent / Task Scheduler / systemd timer）
3. 后续任务通过 `~/.config/remind-me-skill/tasks/<epoch>_<pid>.task` 持久化，重启后由 wakeup_handler 补提醒

---

*技术栈分析：2026-07-13*

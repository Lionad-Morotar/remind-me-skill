<!-- refreshed: 2026-07-13 -->
# 架构

**分析日期：** 2026-07-13

## 系统概览

```text
┌─────────────────────────────────────────────────────────────┐
│                  Skill 主入口（LLM 路由层）                  │
│                      `SKILL.md`                             │
└──────────────┬──────────────┬──────────────┬───────────────┘
               │              │              │
               ▼              ▼              ▼
┌──────────────────┐ ┌────────────────┐ ┌────────────────────┐
│  reminder /      │ │   stickies     │ │      break         │
│  calendar        │ │                │ │   （跨平台自建）    │
│  (macOS App      │ │  (macOS GUI +  │ │                    │
│   AppleScript)   │ │   RTF 剪贴板)  │ │  后台进程 + 系统    │
│  `references/`   │ │ `references/`  │ │   调度器           │
│  `reminder-help` │ │ `stickies-help`│ │  `references/`     │
│  `calendar-help` │ │ + `scripts/`   │ │  `break-help`      │
└──────────────────┘ └────────────────┘ └─────────┬──────────┘
                                                  │
                       ┌──────────────────────────┼──────────────────────────┐
                       ▼                          ▼                          ▼
              ┌────────────────┐        ┌────────────────┐        ┌──────────────────┐
              │     macOS      │        │    Windows     │        │      Linux       │
              │ LaunchAgent +  │        │ Task Scheduler │        │ systemd user     │
              │ sleep +        │        │ + PowerShell   │        │ timer + zenity/  │
              │ osascript      │        │ MsgBox         │        │ kdialog          │
              │ `scripts/`     │        │ `scripts/win..`│        │ `scripts/linux/` │
              └────────┬───────┘        └────────┬───────┘        └─────────┬────────┘
                       │                          │                          │
                       └──────────────────────────┼──────────────────────────┘
                                                  ▼
                              ┌────────────────────────────────────┐
                              │  Task 文件存储（跨平台共享协议）   │
                              │  `~/.config/remind-me-skill/`      │
                              │  `tasks/<target_epoch>_<pid>.task` │
                              └────────────────────────────────────┘
```

## 组件职责

| 组件 | 职责 | 文件 |
|-----------|----------------|------|
| Skill 入口 | 按 `--type` 路由到对应 reference，决策指南 + 扩展说明 | `SKILL.md` |
| Reminder 指南 | AppleScript 操作 Reminders.app（含 due date 触发、陷阱、幂等清理） | `references/reminder-help.md` |
| Calendar 指南 | AppleScript 操作 Calendar.app（全天事件 + display alarm） | `references/calendar-help.md` |
| Stickies 指南 | GUI/System Events + RTF 剪贴板灌入桌面便签 | `references/stickies-help.md` |
| Break 指南 | 跨平台自建后台进程 + 系统调度器强制打断 | `references/break-help.md` |
| macOS 实现 | `create_reminder.sh`、`wakeup_handler.sh`、`install_agent.sh`、`cancel_task.sh`、`list_tasks.sh`、`cleanup_expired.sh` | `scripts/` |
| Windows 实现 | PowerShell 同构脚本 | `scripts/windows/` |
| Linux 实现 | Bash 同构脚本 + zenity/kdialog | `scripts/linux/` |
| Stickies RTF 生成 | Swift 脚本生成 RTFD+RTF 双类型剪贴板（富文本+图片） | `scripts/stickies_make_rtf.swift` |
| Linux 调度单元 | systemd user service + timer 定义 | `systemd/remind-me.service`, `systemd/remind-me.timer` |

## 模式概览

**总体：** 路由分发（Router）+ 平台适配（Platform Adapter）+ 文件契约（File-based Contract）

**关键特征：**
- **SKILL.md 仅做路由**：四 type（reminder/calendar/stickies/break）按场景分流，详情全在 `references/<type>-help.md`
- **同构跨平台**：break 在 macOS/Windows/Linux 三平台提供同名脚本（仅扩展名差异），调用方无需感知平台
- **任务文件即协议**：`<target_epoch>_<pid>.task` 文本键值对文件是跨平台共享契约，后台进程、唤醒 handler、清理脚本都围绕它协作
- **外部系统调度器接管持久化**：LaunchAgent / Task Scheduler / systemd timer 负责唤醒后补提醒，后台 `sleep` 进程只负责"在电脑前"场景

## 分层

**LLM 路由层：**
- 用途： 根据用户意图选择 type，加载对应 reference 的完整知识
- 位置： `SKILL.md`
- 包含： 决策矩阵、type 扩展说明
- 依赖： 无（静态 markdown）
- 被使用方： Claude / 支持 SlashCommand 的 IDE

**Reference 指南层：**
- 用途： 每个 type 的完整实操手册（API 调用、陷阱、模板）
- 位置： `references/`
- 包含： 场景定位、代码模板、实测陷阱、平台差异
- 依赖： 对应平台系统 App 或自建脚本
- 被使用方： SKILL.md 路由后被 LLM 加载

**平台实现层：**
- 用途： 实际创建任务、维护调度器、处理唤醒
- 位置： `scripts/`, `scripts/windows/`, `scripts/linux/`
- 包含： POSIX sh / PowerShell / Swift
- 依赖： `osascript`、`launchctl`、Task Scheduler、systemd、zenity/kdialog、AppKit
- 被使用方： break-help.md 中的调用示例

**数据契约层：**
- 用途： 任务元数据持久化，供唤醒/清理/取消协作
- 位置： `~/.config/remind-me-skill/tasks/`（运行时，不在仓库内）
- 包含： `<target_epoch>_<pid>.task` 键值对文件
- 字段： `TITLE`, `MESSAGE`, `CREATED_AT`, `TARGET_AT`, `PID`

## 数据流

### 创建 break 型提醒（主路径）

1. LLM 读 `SKILL.md`，按语义或 `--type break` 路由到 `references/break-help.md`
2. 按平台检测脚本：`scripts/create_reminder.sh` / `scripts/windows/create_reminder.ps1` / `scripts/linux/create_reminder.sh`
3. 脚本完成四件事：计算 wait_seconds → 后台 spawn `(sleep && osascript/dialog && rm task)` → 写 task 文件 → 注册/确认系统调度器（LaunchAgent/Task Scheduler/systemd timer）
4. 脚本 stdout 输出 PID，LLM 按 `break-help.md` 模板格式化返回用户

### 过期补提醒（次路径）

1. 用户唤醒 / 登录 / 解锁触发系统调度器
2. macOS: `~/Library/LaunchAgents/com.local-link.remind-me.plist` 每分钟触发 `scripts/wakeup_handler.sh`
3. Windows: Task Scheduler `RemindMe-Skill-Wakeup` 触发 `scripts/windows/wakeup_handler.ps1`
4. Linux: `systemd/remind-me.timer` 每分钟触发 `scripts/linux/cleanup_expired.sh`
5. 各 wakeup handler 扫 task 目录，对 `TARGET_AT < now` 的任务弹 `[过期提醒]` 对话框，确认即删、稍后即推迟 30 分钟

### Stickies 便签创建（独立路径）

1. LLM 读 `references/stickies-help.md`
2. 修改 `scripts/stickies_make_rtf.swift` 顶部 `blocks`/`imgPath`，`swift scripts/stickies_make_rtf.swift` 将 RTFD + flat RTF 双类型写剪贴板
3. GUI 流程（System Events）：Cmd+N → 点颜色菜单 → Cmd+V → 设 size/position
4. 贴后复查 window 数量与位置确认不重叠

**状态管理：**
- 无内存状态。所有状态通过 task 文件 + 系统调度器配置持久化
- 后台进程本身不持有状态，仅持有 `$task_file` 路径用于结束时自清理

## 关键抽象

**Task File（任务文件契约）：**
- 用途： 单个提醒任务的可持久化描述，是后台进程 / wakeup handler / 清理脚本 / 取消脚本间的唯一通信载体
- 示例： `~/.config/remind-me-skill/tasks/1771021956_37802.task`
- 模式： 文件即消息（file-as-message），文件名编码 `<target_epoch>_<pid>` 便于无解析排序与按 PID 取消

**Type Router（类型路由）：**
- 用途： 把"提醒"这个笼统意图拆分到四种语义不同的实现
- 示例： `SKILL.md` 的 type 表格、`--type` 参数
- 模式： 命令分发 + 策略模式（每个 type 是一种策略，reference 是策略实现文档）

**Platform Adapter（平台适配）：**
- 用途： 同一 break 概念在三平台的差异化实现
- 示例： `scripts/create_reminder.sh` vs `scripts/windows/create_reminder.ps1` vs `scripts/linux/create_reminder.sh`
- 模式： 同名同参不同实现，由 reference 文档在调用前进行平台检测后选脚本

## 入口点

**Skill 入口：**
- 位置： `SKILL.md`
- 触发方式： 用户通过 SlashCommand `/remind-me` 或在提示词中提及 "remind-me-skill"
- 职责： 参数解析（标题/内容/时间/type）→ 路由到对应 reference

**Break 创建入口：**
- 位置： `scripts/create_reminder.sh` (macOS) / `scripts/windows/create_reminder.ps1` / `scripts/linux/create_reminder.sh`
- 触发方式： LLM 按 `references/break-help.md` 调用
- 职责： 创建 task 文件 + spawn 后台 sleep 进程 + 注册系统调度器

**唤醒处理入口：**
- 位置： `scripts/wakeup_handler.sh` / `scripts/windows/wakeup_handler.ps1` / `scripts/linux/cleanup_expired.sh`
- 触发方式： LaunchAgent 每分钟 / Task Scheduler 登录解锁 / systemd timer 每分钟
- 职责： 扫过期任务 → 弹对话框 → 确认删除或推迟 30 分钟

## 架构约束

- **线程：** 所有脚本均为单线程；并发通过后台 `&` 子 shell 进程 + 系统调度器周期性触发实现
- **全局状态：** 无进程内全局状态；`~/.config/remind-me-skill/tasks/` 是唯一的共享可变状态，通过文件锁-free 的原子写入 + PID 命名规避竞争
- **平台依赖:** reminder/calendar/stickies 强依赖 macOS App（Reminders/Calendar/Stickies）+ AppleScript，无跨平台路径；break 是唯一跨平台 type
- **AppleScript 陷阱:** 不设 `remind` 属性、日期组件按 day→month→year 顺序、多行用 `& return &` 而非 `\n`（详见 `references/reminder-help.md`、`references/calendar-help.md`）
- **Stickies 能力边界:** Stickies.app 无 AppleScript 对象模型，富文本必须走 Swift + RTFD 剪贴板通道，不能用 JXA 或 `textutil`

## 反模式

### 在 SKILL.md 展开具体实现细节

**场景：** 把 AppleScript 模板、平台脚本参数写进 `SKILL.md`
**为什么不对：** `SKILL.md` 在每次 skill 加载时都进上下文，膨胀会浪费 token 且难维护；四 type 的细节应延迟到按需加载
**正确做法：** 在 `references/<type>-help.md` 中写细节，`SKILL.md` 仅保留决策矩阵 + 一行 reference 链接

### 给 break 之外用后台 sleep 进程

**场景：** reminder/calendar 也走 `scripts/create_reminder.sh`
**为什么不对：** 后台 sleep 在关机时丢失，且 reminder/calendar 有系统 App 原生调度（due date / display alarm），无需自建
**正确做法：** reminder 设 `due date`，calendar 设 `display alarm`，让系统 App 接管提醒时机

### 用 JXA 或 textutil 处理 Stickies 富文本图片

**场景：** 试图用 JXA `initWithString:` 或 `textutil -convert rtf` 构造/扁平化带图 RTFD
**为什么不对：** JXA ObjC bridge 对 NSAttributedString 重载 selector 系统性盲区；`doc.rtf(from:)` 与 `textutil` 都会丢 NSTextAttachment
**正确做法：** 用 `scripts/stickies_make_rtf.swift`（AppKit + FileWrapper + RTFD），剪贴板同时写 `.rtfd` + `.rtf`

### 直接 `set month` 导致跨月溢出

**场景：** AppleScript 中 `set month of theDate to m` 在 31 号设置到 30 天的月份会溢出到下一个月
**为什么不对：** AppleScript `current date` 组件赋值顺序敏感
**正确做法：** 先 `set day of theDate to d`，再 `set month`，最后 `set year`（见 `references/reminder-help.md`、`references/calendar-help.md`）

## 错误处理

**策略：** 脚本内 `set -euo pipefail`（Bash）/ `$ErrorActionPreference = "Stop"`（PowerShell），失败即非零退出；LLM 层在 reference 中以"陷阱"形式预防已知错误

**模式：**
- 任务文件写入失败 → 脚本退出，不注册调度器，避免孤儿任务
- 后台进程被 kill → task 文件残留 → 下次 wakeup handler 检测到 `TARGET_AT` 过期会再次提醒（幂等）
- 对话框超时（macOS 5 分钟 / Windows 默认）→ 不删除任务，下次唤醒再提醒

## 横切关注点

**日志：** macOS LaunchAgent stdout/stderr → `/tmp/remind-me-skill.log`；Linux 通过 `journalctl --user -u remind-me.service`；Windows 无集中日志，依赖 MessageBox 反馈
**校验：** reference 文档以"陷阱"章节形式提供静态校验清单（AppleScript 顺序、RTFD 构造、剪贴板双类型）
**认证：** 无。所有操作在用户会话内完成，依赖系统级 UI 权限（macOS 辅助功能、Windows 用户登录会话）

---

*架构分析：2026-07-13*

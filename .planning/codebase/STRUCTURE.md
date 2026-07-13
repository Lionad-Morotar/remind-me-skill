# 代码库结构

**分析日期：** 2026-07-13

## 目录布局

```
remind-me-skill/
├── SKILL.md                    # Skill 主入口：四 type 路由 + 决策矩阵
├── Agents.md                   # Agent 上下文说明（文档地图）
├── README.md                   # 项目说明、使用示例、安装指引
├── CHANGELOG.md                # 版本变更日志（Keep a Changelog）
├── docs/                       # 文档附件
│   └── example.png             # 中断型对话框示例截图
├── references/                 # 四 type 的完整实操手册（按 type 拆分）
│   ├── reminder-help.md        # Reminders.app：任务型、due date 触发
│   ├── calendar-help.md        # Calendar.app：一次性、全天事件 + alarm
│   ├── stickies-help.md        # Stickies.app：桌面便签、RTF 剪贴板
│   └── break-help.md           # 跨平台自建后台进程 + 系统调度器
├── scripts/                    # 平台实现脚本
│   ├── create_reminder.sh      # macOS 创建任务 + 注册 LaunchAgent
│   ├── cancel_task.sh          # macOS 按 PID 取消
│   ├── list_tasks.sh           # macOS 列出在途/过期任务
│   ├── cleanup_expired.sh      # macOS 标记过期并发通知
│   ├── wakeup_handler.sh       # macOS 唤醒时过期确认（内部）
│   ├── install_agent.sh        # macOS 安装 LaunchAgent（内部）
│   ├── stickies_make_rtf.swift # Stickies RTFD 剪贴板生成
│   ├── linux/                  # Linux 同构实现
│   │   ├── create_reminder.sh
│   │   ├── cancel_task.sh
│   │   ├── list_tasks.sh
│   │   ├── cleanup_expired.sh
│   │   ├── install_agent.sh
│   │   ├── dialog.sh           # zenity/kdialog 通用对话框（内部）
│   │   └── wakeup_handler.sh
│   └── windows/                # Windows 同构实现（PowerShell）
│       ├── create_reminder.ps1
│       ├── cancel_task.ps1
│       ├── list_tasks.ps1
│       ├── cleanup_expired.ps1
│       ├── install_agent.ps1
│       └── wakeup_handler.ps1
└── systemd/                    # Linux systemd user 单元定义
    ├── remind-me.service
    └── remind-me.timer
```

## 目录用途

**`references/`：**
- 用途： 四 type 的完整实操知识库，供 SKILL.md 路由后按需加载
- 包含： 场景定位、API 模板、实测陷阱、平台差异、完整流程
- Key files: `references/reminder-help.md`、`references/calendar-help.md`、`references/stickies-help.md`、`references/break-help.md`
- Convention: 新增 type 时在此目录加 `<type>-help.md`，并在 `SKILL.md` 决策矩阵加一行

**`scripts/`：**
- 用途： macOS 平台脚本 + Stickies 专用 Swift 工具
- 包含： POSIX sh、Swift
- Key files: `scripts/create_reminder.sh`（入口）、`scripts/wakeup_handler.sh`（过期处理）、`scripts/stickies_make_rtf.swift`（RTFD 生成）

**`scripts/linux/` 与 `scripts/windows/`：**
- 用途： break 型提醒的 Linux / Windows 同构实现
- 包含： 与 `scripts/` 根下脚本同名同参，仅实现技术栈不同
- Convention: 三平台脚本必须保持同名、同参数顺序、同输出格式（stdout 末行 PID）

**`systemd/`：**
- 用途： Linux systemd user service + timer 定义模板
- 包含： unit 文件
- Key files: `systemd/remind-me.service`、`systemd/remind-me.timer`
- Note: macOS 的 LaunchAgent plist 与 Windows 的 Task Scheduler XML 由 `install_agent.sh` / `install_agent.ps1` 运行时生成，不入库

**`docs/`：**
- 用途： README 引用的截图等静态资源
- 包含： 图片
- Key files: `docs/example.png`

## 关键文件位置

**Entry Points:**
- `SKILL.md`: Skill 主入口，LLM 路由层
- `references/break-help.md`: break 型跨平台调用入口文档
- `scripts/create_reminder.sh`: macOS 运行时入口（被 reference 引用）

**Configuration:**
- 仓库内无运行时配置文件；macOS LaunchAgent plist 由 `scripts/install_agent.sh` 写入 `~/Library/LaunchAgents/com.local-link.remind-me.plist`
- Linux systemd unit 源文件在 `systemd/`，由 `scripts/linux/install_agent.sh` 拷贝到 `~/.config/systemd/user/`
- Windows Task Scheduler 任务由 `scripts/windows/install_agent.ps1` 注册

**Core Logic:**
- `scripts/create_reminder.sh` (47 行): 创建任务 + spawn 后台进程 + 注册调度器
- `scripts/wakeup_handler.sh` (42 行): 过期任务对话框处理
- `scripts/install_agent.sh` (60 行): LaunchAgent 安装
- `scripts/stickies_make_rtf.swift`: AppKit RTFD 剪贴板生成

**Testing:**
- 无自动化测试目录；验证依赖 reference 文档中的"贴后验证""陷阱"章节手动核对

## 命名规范

**Files:**
- Reference 文档：`<type>-help.md`（kebab-case，与 type 名一致）
  - 示例：`reminder-help.md`、`calendar-help.md`、`stickies-help.md`、`break-help.md`
- Shell 脚本：snake_case，动词_名词
  - 示例：`create_reminder.sh`、`cancel_task.sh`、`list_tasks.sh`、`wakeup_handler.sh`
- 平台子目录：小写平台名 `linux/`、`windows/`；macOS 脚本直接在 `scripts/` 根（历史约定，默认平台）
- Swift 工具：snake_case，`<domain>_<verb>_<noun>.swift`
  - 示例：`stickies_make_rtf.swift`

**Directories:**
- 全小写，单词间无分隔符（`references/`、`scripts/`、`systemd/`）

**任务文件（运行时，不入库）：**
- 路径：`~/.config/remind-me-skill/tasks/<target_epoch>_<pid>.task`
- 命名编码目标时间戳与 PID，便于按时间排序与按 PID 取消

## 新增代码位置

**新增提醒 type：**
- 文档：`references/<new-type>-help.md`
- 路由：`SKILL.md` 决策矩阵加一行
- 如需脚本：按平台放入 `scripts/`（macOS）、`scripts/linux/`、`scripts/windows/`，保持同名同参

**新增 macOS break 辅助脚本：**
- 实现：`scripts/<verb>_<noun>.sh`
- 调用文档：更新 `references/break-help.md` 的 macOS 脚本表

**新增 Linux/Windows break 脚本：**
- 实现：`scripts/linux/<name>.sh` 或 `scripts/windows/<name>.ps1`
- 要求：与 macOS 同名脚本参数、stdout 格式一致
- 调用文档：更新 `references/break-help.md` 对应平台脚本表

**修改 Stickies 富文本模板：**
- 编辑：`scripts/stickies_make_rtf.swift` 顶部 `blocks` 数组与 `imgPath`
- 使用说明：`references/stickies-help.md`

**共享工具：**
- 当前无跨脚本共享库；如需提取公共函数，建议在 `scripts/lib/` 新建并被各平台脚本 source（Bash）/ dot-source（PowerShell）

## 特殊目录

**`~/.config/remind-me-skill/`（运行时，仓库外）：**
- 用途： 任务文件存储 + 可能的日志
- Generated: 是（由 `create_reminder.sh` 首次运行时创建）
- Committed: 否

**`~/Library/LaunchAgents/com.local-link.remind-me.plist`（macOS 运行时）：**
- 用途： LaunchAgent 定义，每分钟触发 `wakeup_handler.sh`
- Generated: 是（由 `scripts/install_agent.sh` 写入）
- Committed: 否

**`/tmp/remind-me-skill.log`（macOS 运行时）：**
- 用途： LaunchAgent stdout/stderr 日志
- Generated: 是
- Committed: 否

---

*Structure analysis: 2026-07-13*

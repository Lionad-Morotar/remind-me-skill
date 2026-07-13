# 测试规范

**分析日期：** 2026-07-13

## 现状

**本项目当前没有任何测试。**

具体缺失：

- 无测试框架（无 BATS、无 shunit2、无 Pester、无 XCTest）
- 无测试文件（无 `*.test.*`、无 `*.spec.*`、无 `tests/`、无 `test_*.sh`）
- 无测试运行器配置（无 `jest.config.*`、无 `vitest.config.*`、无 `Makefile test` 目标）
- 无 CI 流水线（无 GitHub Actions、无 GitLab CI）
- 无覆盖率工具
- 无静态分析配置（无 shellcheck、无 PSScriptAnalyzer）

项目规模：约 1012 行脚本（Bash 约 660 行、PowerShell 约 261 行、Swift 91 行）+ 5 份 references 文档 + 2 个 systemd unit。

## 为何当前缺失合理

- 项目定位为 Claude Code Skill，运行环境由代理调用而非人手动执行
- 主要逻辑薄（shell 脚本 + sleep + 系统通知调用），核心复杂度集中在"系统行为"而非"业务逻辑"
- 三平台差异（macOS / Linux / Windows）使得跨平台单元测试成本高
- 系统集成（osascript / systemd / Task Scheduler / zenity / kdialog / AppleScript）难以在测试环境模拟
- references/*.md 中的 AppleScript 是"陷阱文档"，本质是给人和代理看的经验记录，不是可测代码

## 风险（随规模增长会加剧）

**回归脆弱点：**

- `scripts/create_reminder.sh` 任务文件格式（`KEY=VALUE`）是三平台共享契约，任何平台改动字段会跨平台 break
- `scripts/wakeup_handler.sh` 与 `scripts/cleanup_expired.sh` 的 `NOTIFIED` 状态机靠 grep + sed 手工维护，易漏边界
- `scripts/linux/dialog.sh` 多工具降级链（zenity → kdialog → notify-send → none）无回退路径测试
- `references/reminder-help.md` / `calendar-help.md` 中 `date -v` 动态算日期的 AppleScript 陷阱（月底溢出）只能人工复现
- PowerShell 与 Bash 双实现的字段写入一致性（`Set-Content -Encoding UTF8` vs `cat > ... << EOF`）未验证 BOM / 换行差异

## 建议的测试分层

如未来需要建立测试，建议从轻到重分三层：

### 第一层：静态分析（低成本，立即收益）

引入工具：

- **shellcheck**（针对 `scripts/**/*.sh`）：捕获未引用变量、glob 风险、POSIX 兼容问题
- **PSScriptAnalyzer**（针对 `scripts/windows/*.ps1`）：捕获 cmdlet 误用、不安全别名
- **swiftc -warnings**（针对 `scripts/stickies_make_rtf.swift`）：基础类型检查

集成方式：在项目根放一个 `Makefile` 或 `justfile`，加 `make lint` 目标；不要求 CI，本地手动跑即可。

预期收益：一次性投入约 30 分钟，能持续捕获 70% 的低级错误。

### 第二层：脚本纯函数单测（中等成本）

引入框架：

- **BATS**（Bash Automated Testing System）针对 `scripts/*.sh`、`scripts/linux/*.sh`
- **Pester** 针对 `scripts/windows/*.ps1`

可测的纯逻辑（不依赖 GUI / systemd / osascript）：

- 任务文件字段解析：`grep "^TARGET_AT=" | cut -d= -f2` 的边界（空文件、缺字段、含 `=` 的 value）
- 时间计算：`wait_seconds=$((target_epoch - now))` 的过期判定
- `date -r` / `date -d` fallback 行为（可注入 stub `date`）
- `dialog.sh` 的工具检测函数 `_detect_dialog_tool`（mock `command -v` 输出）
- `list_tasks.sh --expired` 过滤逻辑

测试文件命名建议：`tests/bats/create_reminder.bats`、`tests/pester/create_reminder.Tests.ps1`，与 `scripts/` 平行。

### 第三层：端到端集成测试（高成本，低优先级）

不建议立即做。如确实需要：

- 用 `launchctl` 的 user domain 在 macOS VM 中跑真实 `create_reminder.sh`，验证 LaunchAgent 写入
- Windows 端用 `Register-ScheduledTask` + `schtasks /query` 验证 Task Scheduler 注册
- Linux 端用 `systemd --user` 容器（如 `podman run --systemd=always`）验证 timer 激活

集成测试成本远高于收益，建议在用户报告 bug 后再针对该 bug 补一条集成用例。

## 建议的 mock 策略

如引入 BATS 单测，关键 mock 点：

| 系统调用 | 替换方式 |
| --- | --- |
| `osascript` | 注入 `PATH` 前置的 stub 脚本，记录参数到临时文件 |
| `date` | 在 stub 脚本中根据第一个参数返回固定值（如 `date +%s` → 固定 epoch） |
| `launchctl` | stub 返回 `0`，记录加载的 plist 路径 |
| `zenity` / `kdialog` / `notify-send` | stub `command -v` 输出，控制 `_detect_dialog_tool` 走向 |
| `Start-Job`（PowerShell） | Pester `Mock Start-Job { [PSCustomObject]@{ Id = 12345 } }` |

不可 mock 的部分（应留给集成测试或人工验证）：

- AppleScript 的 `tell application "Reminders"` / `tell application "Calendar"` 行为
- Stickies 的 GUI 操作（System Events 键击、剪贴板 RTF 粘贴）
- 系统睡眠 / 唤醒时机

## 建议的目录结构（如建立测试）

```
tests/
├── bats/
│   ├── create_reminder.bats
│   ├── list_tasks.bats
│   ├── wakeup_handler.bats
│   └── helpers/
│       └── stubs/          # osascript/date/launchctl stub 脚本
├── pester/
│   ├── create_reminder.Tests.ps1
│   └── list_tasks.Tests.ps1
└── fixtures/
    ├── sample.task         # 标准任务文件样本
    └── expired.task        # 过期未确认样本
```

## 建议的运行命令（如建立测试）

```bash
# 静态分析
shellcheck scripts/**/*.sh
Invoke-ScriptAnalyzer -Path scripts/windows -Recurse

# BATS（需 brew install bats-core）
bats tests/bats/

# Pester（PowerShell 内置）
Invoke-Pester tests/pester/
```

## 测试覆盖建议优先级

如只能投入有限时间，建议按此顺序覆盖：

| 优先级 | 目标 | 理由 |
| --- | --- | --- |
| P0 | `wakeup_handler.sh` 的 NOTIFIED 状态机 | 出错会导致用户收不到过期提醒（数据丢失） |
| P0 | `create_reminder.sh` 任务文件写入格式 | 三平台共享契约 |
| P1 | `dialog.sh` 工具降级链 | Linux 端用户体验直接相关 |
| P1 | `date -r` / `date -d` fallback | macOS / Linux 兼容性 |
| P2 | `list_tasks.sh --expired` 过滤 | 展示正确性，出错影响小 |
| P2 | PowerShell 字段写入与 Bash 一致性 | 跨平台解析正确性 |
| P3 | `stickies_make_rtf.swift` 输出 | 仅在生成便签时跑，人工验证成本低 |
| P3 | AppleScript 示例 | 本质不可自动测，靠人工 + references 文档约束 |

## 当前推荐策略

**短期：不引入测试框架，先做 lint。**

具体动作：

1. 加 `Makefile` 提供 `make lint`（shellcheck + PSScriptAnalyzer）
2. 在 README 或 Agents.md 中加一节"开发约定"，列出 shellcheck 通过为合入前提
3. 不修历史脚本中已存在的 lint warning，只要求新增脚本通过

**中期：当任务文件格式或 wakeup_handler 状态机要改动时，再补对应 BATS 用例。**

不要预防性地全量补测试，因为：

- 项目变更频率低（近期 commits 多为文档调整）
- 脚本薄，bug 主要出现在"系统集成"而非"算法逻辑"
- BATS 维护成本与脚本本身相当

---

*Testing analysis: 2026-07-13*

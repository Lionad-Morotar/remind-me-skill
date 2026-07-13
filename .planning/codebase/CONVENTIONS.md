# 编码约定

**分析日期：** 2026-07-13

## 项目性质

remind-me-skill 是一个 Claude Code Skill（技能包），非传统软件项目：

- 无 `package.json` / `pyproject.toml` / `Cargo.toml` 等包管理清单
- 无构建系统、无编译步骤
- 无 lint / formatter 配置文件
- 由 Markdown 文档（SKILL.md、references/、README.md、CHANGELOG.md、Agents.md）+ 多语言脚本（Bash、PowerShell、Swift、AppleScript）+ 系统配置（systemd unit）组成
- 目标用户为 Claude Code 代理与人类开发者；运行时数据落盘在 `~/.config/remind-me-skill/tasks/`

## 语言分布

| 语言 | 用途 | 位置 |
| --- | --- | --- |
| Bash | macOS / Linux 平台主脚本 | `scripts/*.sh`, `scripts/linux/*.sh` |
| PowerShell | Windows 平台脚本 | `scripts/windows/*.ps1` |
| Swift | Stickies RTF 剪贴板生成器 | `scripts/stickies_make_rtf.swift` |
| AppleScript | 嵌入 references 文档的示例 | `references/*.md` |
| Markdown | 文档 | 根目录 + `references/` |
| systemd unit | Linux 守护配置 | `systemd/*.timer`, `systemd/*.service` |

## 命名模式

**文件：**
- Bash 脚本：`snake_case.sh`（如 `create_reminder.sh`、`wakeup_handler.sh`、`install_agent.sh`）
- PowerShell 脚本：`snake_case.ps1`（如 `create_reminder.ps1`、`install_agent.ps1`）
- Swift 脚本：`snake_case.swift`（如 `stickies_make_rtf.swift`）
- Reference 文档：`<type>-help.md`（如 `reminder-help.md`、`calendar-help.md`、`stickies-help.md`、`break-help.md`）
- 配置文件：保留目标系统原名（如 `remind-me.timer`、`remind-me.service`）

**目录：**
- 平台默认：`scripts/`（macOS）、`scripts/linux/`、`scripts/windows/`
- 文档：`references/`、`docs/`
- 系统配置：`systemd/`

## Bash 脚本约定

参考样例：`scripts/create_reminder.sh`、`scripts/linux/dialog.sh`

**Shebang 与文件头：**
```bash
#!/bin/bash
# 创建定时提醒任务
```
- 首行 `#!/bin/bash`
- 第二行单行中文注释描述脚本职责
- 不使用 `set -euo pipefail`，通过显式错误检查 + `exit 1` 处理失败

**参数解析：**
```bash
title="${1:-提醒}"
message="${2:-时间到了！}"
target_epoch="$3"
```
- 使用 `${1:-默认值}` 提供 fallback，避免空字符串
- 必选参数（如 `target_epoch`）不写默认值，显式校验后退出

**变量：**
- 全部使用 `snake_case` 小写（`config_dir`、`tasks_dir`、`task_file`、`target_at`、`notified`）
- 始终双引号包围变量引用：`"$tasks_dir/$name"`
- 命令替换用 `$(...)`，不用反引号

**错误处理：**
```bash
if [ "$wait_seconds" -le 0 ]; then
  echo "错误：目标时间已过" >&2
  exit 1
fi
```
- 错误信息重定向到 stderr：`>&2`
- 错误消息使用中文（面向中文用户）
- 退出码：`0` 成功，`1` 通用错误
- 容忍非关键失败：`2>/dev/null || true`（如 `osascript`、`launchctl`）

**条件与控制流：**
- 使用 POSIX 风格 `[ ... ]`，不用 `[[ ... ]]`
- 短路链：`[ -d "$tasks_dir" ] || { echo "没有在途任务"; exit 0; }`
- for 循环遍历任务文件：始终加 `[ -f "$task_file" ] || continue` 防空 glob

**跨平台兼容（Bash）：**
- `date -r`（macOS）与 `date -d @`（Linux）fallback：
  ```bash
  target_time=$(date -r "$target_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null \
    || date -d "@$target_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
  ```
- `sed` 不使用 `-i`（macOS / GNU 行为不一致），改用临时文件：
  ```bash
  sed "s/^TARGET_AT=.*/TARGET_AT=$new_target/" "$task_file" > "${task_file}.tmp" && \
    mv "${task_file}.tmp" "$task_file"
  ```

**函数（Linux 对话框抽象 `scripts/linux/dialog.sh`）：**
- 内部辅助函数加下划线前缀：`_detect_dialog_tool()`
- 对外函数使用 `local` 限定变量作用域
- 通过 `case "$DIALOG_TOOL" in ... esac` 多路分发，按可用工具降级
- 模块导出：`export -f dialog_info dialog_confirm dialog_notify`
- 其他脚本用 `source "$script_dir/dialog.sh"` 加载

## PowerShell 脚本约定

参考样例：`scripts/windows/create_reminder.ps1`

**参数块：**
```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$Title = "提醒",
    [Parameter(Mandatory=$true)]
    [string]$Message = "时间到了！",
    [Parameter(Mandatory=$true)]
    [long]$TargetEpoch
)
```
- 使用 `param(...)` + `[Parameter(Mandatory=$true)]` 声明必填参数
- 类型显式标注：`[string]`、`[long]`
- 为可选参数提供中文默认值

**变量命名：**
- PascalCase：`$configDir`、`$tasksDir`、`$taskFile`、`$waitSeconds`、`$TargetEpoch`
- 与 Bash 的 snake_case 形成语言内一致的差异

**惯用 cmdlet：**
- 路径拼接：直接字符串插值 `"$env:USERPROFILE\.config\remind-me-skill"`
- 目录创建：`New-Item -ItemType Directory -Force -Path $tasksDir | Out-Null`
- 脚本目录：`Split-Path -Parent $MyInvocation.MyCommand.Path`
- 后台任务：`Start-Job -ScriptBlock { ... } -ArgumentList ...`
- 时间戳：`[DateTimeOffset]::Now.ToUnixTimeSeconds()`
- 错误：`Write-Error "..."; exit 1`
- Here-string 写任务文件：`@"..."@ | Set-Content -Path $taskFile -Encoding UTF8`

## Swift 脚本约定

参考样例：`scripts/stickies_make_rtf.swift`

- Shebang：`#!/usr/bin/env swift`
- 顶部中文注释块说明用途、用法、与 GUI 步骤的衔接
- 顶层命令式代码（不使用 `main()` 包装）
- 常量命名：`let C_TITLE = rgb(...)`（大写 + 下划线，表示调色板）
- 函数命名：camelCase，参数使用外部标签：`func pingfang(_ size: CGFloat, _ bold: Bool, _ italic: Bool) -> NSFont`
- 内容数组用元组列表：`let blocks: [(String, CGFloat, Bool, Bool, NSColor)] = [...]`
- 执行结果用中文 `print(...)` 输出关键指标（字节数、是否含图、下一步指引）
- 错误：`fputs("...\n", stderr); exit(1)`

## AppleScript 约定（references/*.md）

**嵌入位置：**
- 作为示例代码块嵌入 Markdown 文档，非独立 `.scpt` 文件
- 使用 `applescript` 语言标签

**关键模式（`references/calendar-help.md`、`references/reminder-help.md`）：**
- 用 `do shell script "date -v+3m +%Y"` 动态计算日期组件，避免月底跨月溢出
- 日期赋值顺序固定：先 `day` → `month` → `year`
- 多行文本用 `& return &` 拼接，不用 `\n`（AppleScript `\n` 是字面两字符）
- 陷阱在 reference 文档的"陷阱"小节明确列出（如 Reminders 的 `remind` 属性不可写）

## Markdown 文档约定

**SKILL.md（`SKILL.md`）：**
- Frontmatter：`name`、`description`、`argument-hint`、`disable-model-invocation`
- 保持精简：只做路由（type 决策表 + 决策指南），不展开具体实现
- 具体 App 的使用技巧、缺陷、陷阱放到 `references/<type>-help.md`
- 扩展新 type = 新增 reference 文档 + 在 SKILL.md 表格加一行

**references/<type>-help.md：**
- 中文标题 + 中文正文
- 固定小节：适用场景 → 基础/核心创建 → 平台特定细节 → 陷阱 → 脚本参考
- 代码示例一律给可直接运行的完整片段，不省略关键步骤
- 已知"实测"陷阱必须落盘在文档中（如 Stickies 的 JXA 盲区、RTFD 双类型）

**CHANGELOG.md：**
- 遵循 [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
- 遵循 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- 顶层 `## [Unreleased]` + `## [版本] - YYYY-MM-DD` 倒序
- 内部分组：`### Added` / `### Changed` / `### Internal`

**Agents.md：**
- 作为项目上下文指针，仅列出关键文档链接与一句话项目简介
- 不复制 SKILL.md 内容

## 任务文件格式

运行时持久化约定（路径 `~/.config/remind-me-skill/tasks/<target_epoch>_<pid>.task`）：

```
TITLE=<提醒标题>
MESSAGE=<提醒内容>
CREATED_AT=<创建时间戳>
TARGET_AT=<目标时间戳>
PID=<后台进程PID>
NOTIFIED=false
```

- 一行一个 `KEY=VALUE`，无引号、无空格
- KEY 全大写
- `CREATED_AT` / `TARGET_AT` 使用 Unix epoch 秒
- 三平台（Bash / PowerShell）写入完全一致，保证跨平台解析兼容

## 注释风格

- 文件头注释：描述"做了什么"（一行中文）
- 段落级注释：解释"为什么这么做"（如 `-- 用 date -v 动态算目标日期，避免月底跨月溢出`）
- 陷阱注释：明确标注"实测"或"必须"，如 `// 图片附件：必须 fileWrapper（regularFileWithContents 立即持数据 + preferredFilename 识别为 PNG）`
- 不写"TODO"、"FIXME"、"HACK"等开发追踪标记
- 不在注释中夹带外部编号（如 issue 号、PR 号、版本号）

## 版本控制

- 主干分支：`main`
- Commit message 格式：`<type>(<scope>): <subject>`，scope 常见 `skill` / `scripts` / `references`
- Commit 类型：`feat`、`refactor`、`chore`、`docs`、`release`
- 典型历史：`feat(skill): 扩展 remind-me 为四 type 路由，更新 SKILL.md 描述与决策指南`、`refactor(references): 重命名并拆分通知 reference 为四类型 help 文档`
- 忽略规则：`.planning/` 由 GSD 流程生成（项目未明确 ignore，但属工作产物）
- 符号链接：`Claude.md -> Agents.md`（保持两份入口指向同一文档）

## 未检测到的约定

- 无 lint / formatter 配置（`.shellcheckrc`、`.editorconfig`、`.prettierrc` 等均未配置）
- 无格式化工具强制
- 无 CI 流水线（无 `.github/workflows/`、无 `.gitlab-ci.yml`）

---

*Convention analysis: 2026-07-13*

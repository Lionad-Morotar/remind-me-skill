# 项目风险

**分析日期：** 2026-07-13

## 技术债务

**任务文件格式无转义/无 schema：**
- Issue: 任务文件用 shell heredoc 直接展开变量生成 `TITLE=$title` 等键值对，未对 `\n`、`=`、`"` 做转义。标题或内容含这些字符时，`grep "^TITLE=" | cut -d= -f2-` 解析会静默错位
- Files: `scripts/create_reminder.sh:37-44`、`scripts/linux/create_reminder.sh:39-46`、`scripts/windows/create_reminder.ps1`（`@""@` 同样无转义）
- Impact: 用户输入含特殊字符即触发静默 bug；列表/取消/唤醒逻辑全部受影响
- Fix approach: 用 base64 或 JSON 存储；或写入前 `printf %q` / PowerShell `ConvertTo-Json`

**PID 作为任务标识符不可靠：**
- Issue: macOS 用 `kill <pid>` 管理后台 sleep 进程，PID 在系统重启后会被回收复用，`cancel_task.sh <pid>` 可能误杀无关进程；Windows 用 PowerShell Job Id 而非 OS PID，与文档统一用 `kill <pid>` 的指引冲突
- Files: `scripts/cancel_task.sh:23`、`scripts/windows/cancel_task.ps1`（Stop-Job -Id）、`references/break-help.md:62-64`
- Impact: 重启后用户按文档 `kill <pid>` 可能 kill 错进程；Windows 用户照抄命令直接报错
- Fix approach: 任务文件名用 UUID，任务文件内单独记录 OS PID/Job Id，取消时先比对 `PID=` 字段再 kill

**Windows 后台 Job 生命周期脆弱：**
- Issue: `Start-Job` 创建的子任务依附于父 PowerShell 进程，终端关闭 / 父进程退出时 job 立即被回收，定时提醒随之消失，但 `.task` 文件已写入——重启后 `cleanup_expired.ps1` 会把任务误判为"过期补提醒"，产生用户没预期的弹窗
- Files: `scripts/windows/create_reminder.ps1:28-40`
- Impact: Windows 提醒在多数真实使用场景下根本到不了点；过期补提醒逻辑被滥用
- Fix approach: 改用 Task Scheduler 注册一次性 `At <time>` 任务，或 detached `Start-Process -WindowStyle Hidden`

**文档与实现漂移（macOS 任务文件清理）：**
- Issue: `README.md:94-95` 和 `references/break-help.md:40-43` 都写明后台命令为 `sleep ... && osascript ... && rm -f $task_file`，但实际 `scripts/create_reminder.sh:28-31` 只有 `sleep` + `osascript`，**没有 `rm -f`**。任务正常触发后 `.task` 文件残留，`list_tasks.sh` 仍能看到已触发的"在途任务"
- Files: `scripts/create_reminder.sh:28-31` vs `README.md:90-96`、`references/break-help.md:37-43`
- Impact: 任务列表无限膨胀；用户分不清哪些已触发；过期判断 `target_at < now` 会把所有已触发任务归入 `--expired`，语义混乱
- Fix approach: 后台 subshell 末尾补 `rm -f "$task_file"`，或改为 `trap`；同步更新两份文档

**systemd 仓库文件与运行时生成不一致：**
- Issue: 仓库内 `systemd/remind-me.service` 的 `ExecStart=%h/.config/remind-me-skill/scripts/linux/wakeup_handler.sh`，但 `scripts/linux/install_agent.sh:23-36` 生成的 service 用 `$script_dir/wakeup_handler.sh`（实际安装路径是 `~/.agents/skills/remind-me-skill/...`）。两份路径完全不一致，仓库版本是死代码
- Files: `systemd/remind-me.service:7`、`scripts/linux/install_agent.sh:23-36`
- Impact: 维护者改仓库内 service 文件不生效；新贡献者被误导
- Fix approach: 删除仓库内 `systemd/` 目录，或改为模板 + 占位符，让 `install_agent.sh` 真正消费它

**install_agent 静默失败：**
- Issue: `create_reminder.sh:16` 用 `"$script_dir/install_agent.sh" 2>/dev/null || true` 吞掉所有错误。如果 LaunchAgent / systemd / Task Scheduler 装不上，过期补提醒机制直接失效，但用户毫无感知
- Files: `scripts/create_reminder.sh:16`、`scripts/linux/create_reminder.sh:16`、`scripts/windows/create_reminder.ps1:18`
- Impact: 睡眠唤醒补提醒承诺失效，且无任何日志
- Fix approach: 至少把 stderr 落到 `~/.config/remind-me-skill/install.log`，或在 stdout 提示"补提醒机制未就绪"

## 已知缺陷

**Linux `dialog_confirm` 在 notify-send fallback 下永远返回 2：**
- Symptoms: 无 zenity/kdialog 时 fallback 到 `notify-send`，该路径硬编码 `return 2`（取消/超时），过期任务永远无法确认，每次登录反复弹
- Files: `scripts/linux/dialog.sh:78-82`
- Trigger: 在没装 zenity/kdialog 的最小化桌面（如某些 Wayland-only 环境）创建提醒并让其过期
- Workaround: 装 zenity

**`wakeup_handler.sh` 无并发锁：**
- Symptoms: macOS LaunchAgent `StartInterval=60` + `ThrottleInterval=30`，若上次执行未结束（dialog 300s 超时）下次已启动，两个进程同时 `sed` 同一 `.task` 文件，可能写到一半被覆盖
- Files: `scripts/wakeup_handler.sh:36-38`、`scripts/install_agent.sh:42-48`
- Trigger: 用户在过期对话框前发呆超过 60 秒
- Workaround: 无

**`list_tasks.sh` 读取 `NOTIFIED` 但永不写入 `true`：**
- Symptoms: `grep "^NOTIFIED="` 解析存在，但全代码库没有任何位置把 `NOTIFIED=false` 改成 `true`，字段是 dead field
- Files: `scripts/list_tasks.sh:25`、`scripts/cleanup_expired.sh:15-20`、`scripts/wakeup_handler.sh:16`
- Trigger: 总是
- Workaround: 无（功能上暂未依赖该字段，但语义已腐烂）

## 安全考虑

**AppleScript / osascript 注入：**
- Risk: 标题与内容直接以双引号内嵌进 `osascript -e "display dialog \"$message\" ..."`，未做转义。含 `"` 或 `\` 的内容会破坏 AppleScript 语法；精心构造的输入可注入任意 AppleScript（如 `do shell script`）
- Files: `scripts/create_reminder.sh:30`、`scripts/cleanup_expired.sh:26`、`scripts/wakeup_handler.sh:26`
- Current mitigation: 无
- Recommendations: 用 `osascript -e 'on run argv' -e '...' -e 'end run' -- "$title" "$message"` 走参数通道；或先 `sed 's/"/\\"/g'`

**任务文件路径拼接：**
- Risk: `task_file="$tasks_dir/${target_epoch}_${pid}.task"` 中 `target_epoch` 来自命令行参数，未校验是否为纯数字。传 `../../etc/x_1` 类值可写出目录
- Files: `scripts/create_reminder.sh:36`、`scripts/linux/create_reminder.sh:38`
- Current mitigation: 无
- Recommendations: `[[ "$target_epoch" =~ ^[0-9]+$ ]] || exit 1`

## 性能瓶颈

**未识别出实质瓶颈：**
- 脚本均为一次性执行或 60s 级周期任务，无热点路径
- `LaunchAgent StartInterval=60` + 每次扫 `~/.config/remind-me-skill/tasks/*.task` 在任务数 < 1000 时无压力

## 脆弱区域

**AppleScript 字符串陷阱（已在 references 中标注但代码未防御）：**
- Files: `references/reminder-help.md:42-46`、`references/calendar-help.md:52-56`
- Why fragile: `\n` 不是换行、日期组件顺序、多行 body 拼接、`remind` 属性废弃——这些陷阱写在文档里依赖 LLM/人读，没有任何代码层兜底
- Safe modification: 新建 reminder/calendar 时强制走 reference 中的模板；不要随手 `osascript -e 'tell app "Reminders" to make new reminder with properties {name:"...", body:"...多行..."}'`
- Test coverage: 无自动化测试，陷阱只能靠人工/LLM 遵守文档

**Stickies 富文本链路：**
- Files: `scripts/stickies_make_rtf.swift`、`references/stickies-help.md`
- Why fragile: 依赖 AppKit 非公开行为（`rtfd(from:)` 序列化附件、剪贴板双类型、System Events 窗口序）；任一次 macOS 升级都可能破坏
- Safe modification: 改 `blocks` 前完整跑一遍"生成 → 粘贴 → 验证窗口"流程；不要替换 `FileWrapper(regularFileWithContents:)` 为 `FileWrapper(url:)`
- Test coverage: 仅 `print("RTFD bytes=...")` 自检，无断言

## 扩展限制

**任务数：**
- Current capacity: 未实测，估算数百任务内可接受（每个任务一个文件 + 一个后台进程）
- Limit: 每任务一个 `sleep` 子 shell，数千任务会撑爆进程表；`list_tasks.sh` 全量 `grep` 每个文件 O(n)
- Scaling path: 合并为单文件 JSON 存储 + 单一调度进程；或直接迁移到 `at` / `launchd calendar interval`

## 风险依赖

**osascript / AppleScript：**
- Risk: macOS 每年都在收紧 AppleScript 权限（需手动授权"自动化"与"辅助功能"）；新装机器首次调用必弹授权框，无授权即静默失败
- Impact: reminder / calendar / stickies / break(macOS) 四条路径全部依赖
- Migration plan: 无现成替代；短期只能在文档显著位置提示"首次需在系统设置 → 隐私与安全性 → 自动化中授权终端"

**zenity / kdialog（Linux）：**
- Risk: 最小化发行版默认不带，fallback 到 `notify-send` 后 `dialog_confirm` 退化为始终 return 2
- Impact: Linux 过期补提醒不可用
- Migration plan: 检测不到时落到 `whiptail` / `dialog`（TUI），或显式报错要求安装

**PowerShell `Start-Job`：**
- Risk: 见上文"Windows 后台 Job 生命周期脆弱"
- Impact: Windows 提醒链路整体不可靠
- Migration plan: 切到 Task Scheduler 一次性触发

## 缺失关键功能

**无自动化测试 / 无 CI：**
- Problem: 全仓库无任何测试文件、无 GitHub Actions / 任何 CI 配置；跨三平台行为全靠手测
- Blocks: 重构任务文件格式、修 PID 语义、调整 LaunchAgent 间隔等均无回归保护

**无 uninstall 脚本：**
- Problem: `install_agent.sh` 会装 LaunchAgent / systemd timer / Task Scheduler，但没有对应的 `uninstall_agent.sh`，用户无法干净卸载
- Blocks: 用户想彻底移除时需要手动 `launchctl unload`、`systemctl --user disable`、`Unregister-ScheduledTask`

**无版本号 / release 自动化：**
- Problem: `CHANGELOG.md` 已按 Keep a Changelog 维护到 `[0.1.0]`，但仓库内没有 `VERSION` 文件、没有 tag、没有 release 脚本
- Blocks: 通过 `npx skills add` 分发时无法做版本回滚

## 测试覆盖缺口

**全仓库零测试：**
- What's not tested: 三平台创建/取消/列出/过期补提醒全链路；AppleScript 注入防护；任务文件格式边界（含 `\n` / `=` / `"`）；并发 wakeup_handler；PID 复用防御
- Files: 整个 `scripts/`、`scripts/linux/`、`scripts/windows/`
- Risk: 任何重构都可能静默破坏跨平台行为；当前已存在的"create_reminder.sh 缺 rm -f"即为例证
- Priority: **High**——优先补 macOS 主路径的集成测试（哪怕只是 BATS + 临时 `$HOME`），其次 Linux dialog.sh 的分支覆盖，Windows 部分因需要 PowerShell + Windows 环境可暂缓

---

*Concerns audit: 2026-07-13*

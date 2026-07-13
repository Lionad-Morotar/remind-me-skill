# Break 后台定时打断（跨平台）

## 适用场景
**必须强制打断用户**的定时提醒：到点弹系统对话框/通知，支持 macOS / Windows / Linux，支持电脑从睡眠/锁屏唤醒后的过期提醒补发。与 reminder/calendar/stickies（依赖系统 App、仅 macOS）不同，break 靠自建后台进程 + 系统调度器实现。

## 工作流程

1. **检测平台**（macOS / Windows / Linux）
2. **参数解析**：标题、内容、目标时间
3. **计算目标时间戳**（Unix epoch）
4. **调用平台脚本创建任务**：
   - macOS: `scripts/create_reminder.sh "<标题>" "<内容>" <epoch>`
   - Windows: `scripts/windows/create_reminder.ps1 -Title "<标题>" -Message "<内容>" -TargetEpoch <epoch>`
   - Linux: `scripts/linux/create_reminder.sh "<标题>" "<内容>" <epoch>`
5. **返回结果**（严格用以下格式）：
   ```
   已在后台设置提醒任务：
   - 提醒时间：<格式化时间>
   - 提醒内容：<内容>

   后台进程 PID: <pid>

   如果您想取消提醒，可以运行：
   kill <pid>
   ```

## 任务文件格式
路径：`~/.config/remind-me-skill/tasks/<target_epoch>_<pid>.task`
```
TITLE=<提醒标题>
MESSAGE=<提醒内容>
CREATED_AT=<创建时间戳>
TARGET_AT=<目标时间戳>
PID=<后台进程PID>
```

## 后台进程实现
子 shell + sleep：
```bash
(sleep $wait_seconds &&
  osascript -e "display dialog \"内容\" with title \"标题\" buttons {\"OK\"} default button 1 giving up after 60" &&
  rm -f $task_file) &
```

## 过期提醒处理机制
电脑在提醒时间处于睡眠/锁屏时：

**macOS**
1. LaunchAgent 在系统唤醒/登录时触发（每分钟检查一次）
2. 弹对话框 `[过期提醒] xxx`：已确认 → 删任务；稍后 → 推迟 30 分钟
3. 对话框 5 分钟超时自动关闭，下次唤醒再提醒

**Windows**
1. Task Scheduler 在登录/工作站解锁时触发
2. 消息框 `[过期提醒] xxx`：是 → 删任务；否 → 推迟 30 分钟

**Linux**
1. systemd user timer 登录后 30 秒触发（每分钟检查）
2. zenity/kdialog 弹对话框，确认/推迟 30 分钟

## 取消任务
```bash
kill <pid>   # 同时删对应 .task 文件
```

## 系统关机处理
子 shell + sleep 进程在关机时被终止。重启后 `cleanup_expired.sh` 检测过期任务并提醒用户错过的。

## 脚本参考

### macOS
| 脚本 | 用途 |
|------|------|
| `scripts/create_reminder.sh` | 创建任务，自动装 LaunchAgent，返回 PID |
| `scripts/cancel_task.sh <pid>` | 取消指定任务 |
| `scripts/list_tasks.sh` | 列出在途任务（跳过已过期）|
| `scripts/list_tasks.sh --expired` | 列出待确认的过期任务 |
| `scripts/cleanup_expired.sh` | 标记过期任务，发通知 |
| `scripts/wakeup_handler.sh` | 唤醒时处理过期确认（内部）|
| `scripts/install_agent.sh` | 安装 LaunchAgent（内部）|

### Windows
| 脚本 | 用途 |
|------|------|
| `scripts/windows/create_reminder.ps1` | 创建任务，自动装 Task Scheduler |
| `scripts/windows/cancel_task.ps1 -Pid <pid>` | 取消任务 |
| `scripts/windows/list_tasks.ps1` | 列出在途任务 |
| `scripts/windows/cleanup_expired.ps1` | 标记过期任务 |
| `scripts/windows/wakeup_handler.ps1` | 解锁/登录时处理 |

### Linux
| 脚本 | 用途 |
|------|------|
| `scripts/linux/create_reminder.sh` | 创建任务，自动装 systemd service |
| `scripts/linux/cancel_task.sh <pid>` | 取消任务 |
| `scripts/linux/list_tasks.sh` | 列出在途任务 |
| `scripts/linux/cleanup_expired.sh` | 标记过期任务 |
| `scripts/linux/dialog.sh` | 通用对话框（zenity/kdialog，内部）|

## 依赖
- macOS: `osascript`、`date`、`launchctl`（自动处理）
- Windows: PowerShell 5.0+、Windows Forms、Task Scheduler（自动注册）
- Linux: systemd、`zenity`(GTK) 或 `kdialog`(KDE)、`notify-send`(可选)、coreutils

## 技术说明
- macOS LaunchAgent: `~/Library/LaunchAgents/com.local-link.remind-me.plist`，唤醒/登录/挂载时触发，每分钟检查。日志 `/tmp/remind-me-skill.log`
- Windows Task Scheduler: `RemindMe-Skill-Wakeup`，登录/解锁时触发
- Linux: `remind-me.timer`，登录/启动后 30 秒触发，每分钟检查。`journalctl --user -u remind-me.service` 看日志

## 使用示例
```bash
# macOS，5 分钟后
target=$(($(date +%s) + 300))
pid=$(scripts/create_reminder.sh "API 限额重置" "您的 API 限额已重置" $target)

# 查看过期待确认任务
scripts/list_tasks.sh --expired
```

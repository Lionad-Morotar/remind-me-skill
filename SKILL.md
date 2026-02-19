---
name: remind-me-skill
description: 创建 macOS 后台定时提醒任务，在指定时间通过系统通知打断用户。支持睡眠/锁屏后唤醒时的过期提醒确认。当用户需要设置定时提醒、倒计时、闹钟或需要在特定时间点（如"5分钟后"、"下午3点"、API限额重置时间等）收到系统通知时使用。
---

# Remind Me Skill

创建 macOS 后台定时提醒，在指定时间弹出系统对话框打断用户。**新增：支持电脑从睡眠/锁屏状态唤醒后，及时提醒过期通知并获得用户确认。**

## 工作流程

1. **解析用户输入**，提取提醒时间和内容
2. **计算目标时间戳**（Unix epoch）
3. **调用脚本创建任务**：`scripts/create_reminder.sh "<标题>" "<内容>" <目标时间戳>`
4. **返回结果**（必须严格使用以下格式）：
   ```
   已在后台设置提醒任务：
   - 提醒时间：<格式化时间>
   - 提醒内容：<内容>

   后台进程 PID: <pid>

   如果您想取消提醒，可以运行：
   ```
   kill <pid>
   ```
   ```

## 任务管理

在途任务存储在 `~/.config/remind-me-skill/tasks/<timestamp>_<pid>.task`：
- 任务文件格式：TITLE=, MESSAGE=, CREATED_AT=, TARGET_AT=, PID=, NOTIFIED=false
- 提醒触发后：
  - 正常触发：自动删除任务文件
  - 过期触发（唤醒时）：弹出确认对话框，用户确认后删除

### 过期提醒处理机制

当电脑在提醒时间处于睡眠/锁屏状态时：

1. **唤醒检测**：通过 LaunchAgent 在系统唤醒/登录时自动触发检查
2. **过期提醒确认**：弹出对话框 `[过期提醒] xxx`，提供两个选项：
   - **已确认**：删除任务，表示用户已知晓
   - **稍后（30分钟）**：推迟30分钟，下次唤醒或定时再次提醒
3. **超时处理**：对话框5分钟后自动关闭，下次唤醒时再次提醒

## 脚本参考

| 脚本 | 用途 |
|------|------|
| `scripts/create_reminder.sh` | 创建提醒任务，自动安装 LaunchAgent（如未安装），返回 PID |
| `scripts/cancel_task.sh <pid>` | 取消指定任务 |
| `scripts/list_tasks.sh` | 列出所有在途任务（跳过已过期的）|
| `scripts/list_tasks.sh --expired` | 列出待确认的过期任务 |
| `scripts/cleanup_expired.sh` | 标记过期任务，发送通知告知用户唤醒时将弹出确认 |
| `scripts/wakeup_handler.sh` | 唤醒时执行，处理过期提醒确认（内部使用）|
| `scripts/install_agent.sh` | 安装 LaunchAgent（内部使用）|

## 使用示例

**用户**: "5分钟后提醒我 API 限额重置"

**处理**:
```bash
# 1. 解析：当前时间 + 300秒
target=$(($(date +%s) + 300))

# 2. 创建任务（自动安装 LaunchAgent）
pid=$(scripts/create_reminder.sh "API 限额重置" "您的 API 限额已重置" $target)

# 3. 按模板返回结果
```

**查看待确认的过期任务**:
```bash
scripts/list_tasks.sh --expired
```

## 依赖

- macOS `osascript` 用于显示对话框和通知
- `date` 命令用于时间计算
- `launchctl` 用于 LaunchAgent 管理（自动处理）

## 技术说明

- **LaunchAgent**: `~/Library/LaunchAgents/com.local-link.remind-me.plist`
  - 在系统唤醒、登录、挂载磁盘时触发
  - 自动加载，无需用户手动配置
- **日志文件**: `/tmp/remind-me-skill.log` 和 `/tmp/remind-me-skill.error.log`
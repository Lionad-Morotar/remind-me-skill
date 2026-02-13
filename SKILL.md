---
name: remind-me-skill
description: 创建 macOS 后台定时提醒任务，在指定时间通过系统通知打断用户。当用户需要设置定时提醒、倒计时、闹钟或需要在特定时间点（如"5分钟后"、"下午3点"、API限额重置时间等）收到系统通知时使用。
---

# Remind Me Skill

创建 macOS 后台定时提醒，在指定时间弹出系统对话框打断用户。

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
- 任务文件格式：TITLE=, MESSAGE=, TARGET_AT=, PID=
- 提醒触发后自动删除任务文件

**过期任务清理**：使用技能时自动检查并清理过期任务，通过 `scripts/cleanup_expired.sh` 实现。

## 脚本参考

| 脚本 | 用途 |
|------|------|
| `scripts/create_reminder.sh` | 创建提醒任务，返回 PID |
| `scripts/cancel_task.sh <pid>` | 取消指定任务 |
| `scripts/list_tasks.sh` | 列出所有在途任务 |
| `scripts/cleanup_expired.sh` | 清理过期任务 |

## 使用示例

**用户**: "5分钟后提醒我 API 限额重置"

**处理**:
```bash
# 1. 解析：当前时间 + 300秒
target=$(($(date +%s) + 300))

# 2. 创建任务
pid=$(scripts/create_reminder.sh "API 限额重置" "您的 API 限额已重置" $target)

# 3. 按模板返回结果
```

## 依赖

- macOS `osascript` 用于显示对话框
- `date` 命令用于时间计算

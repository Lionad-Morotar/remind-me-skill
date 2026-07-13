---
name: remind-me
description: 创建系统提醒，四种类型按场景分流。reminder=提醒事项 App（任务型、需勾选完成、留列表）；calendar=日历 App（一次性、未来某天、到点即过、事件自动归档）；stickies=桌面便签（常驻展示、富文本+图片）；break=后台定时弹窗强制打断（跨平台、支持睡眠唤醒补提醒）。支持 macOS/Windows/Linux。当用户需要设置定时提醒、倒计时、闹钟、日程事件、桌面便签，或"X 分钟/天/月后提醒我"、"回到某 session 继续"时使用。
argument-hint: "[--type reminder|calendar|stickies|break] <提醒内容> [at <时间>]"
---

# Remind Me Skill

## 工作流程

1. **参数解析**
   1.1 提醒标题和内容
   1.2 时间（如"5 分钟后"、"明天下午 3 点"、"3 个月后"）
   1.3 提醒方式（显式 `--type` 或按语义推断）

2. **按 type 分流**，读取对应 reference 执行：

| --type | App / 机制 | 适用场景 | reference |
|---|---|---|---|
| `reminder`（默认） | Reminders.app | 任务型、需勾选完成、留列表 | [reminder-help.md](references/reminder-help.md) |
| `calendar` | Calendar.app | 一次性、到点即过、未来某天 | [calendar-help.md](references/calendar-help.md) |
| `stickies` | Stickies.app | 桌面常驻展示便签（富文本+图片） | [stickies-help.md](references/stickies-help.md) |
| `break` | 后台定时弹窗（跨平台） | 强制打断、睡眠唤醒补提醒 | [break-help.md](references/break-help.md) |

## type 决策指南

- **一次性、未来某天、到点知晓即可**（"3 个月后复盘"）→ `calendar`（事件过自动归档，不赖列表）
- **任务型、需要勾选完成**（待办清单）→ `reminder`
- **桌面常驻展示**（便签贴桌面）→ `stickies`
- **必须强制打断 / 锁屏睡眠后补提醒 / 非 macOS 平台**→ `break`

无显式 `--type` 时按语义推断，默认 `reminder`。各 App 的使用技巧、缺陷、陷阱**全部在对应 reference**，不在本文件展开。

## 扩展新 type
在 `references/` 新增 `<type>-help.md`，在上表加一行即可。SKILL.md 保持精简路由。

# Calendar 日历事件（macOS）

## 适用场景
**一次性、未来某天、到点即过**的提醒首选 Calendar（如"3 个月后复盘"、"下周三会议"）。事件过了自动成为历史，不像 Reminders 那样赖在列表里需手动勾选完成。

## 创建全天事件 + 提醒
```bash
osascript <<'APPLESCRIPT'
-- 用 date -v 动态算目标日期，避免月底跨月溢出
set y to (do shell script "date -v+3m +%Y") as integer
set m to (do shell script "date -v+3m +%m") as integer
set d to (do shell script "date -v+3m +%d") as integer

set dayStart to current date
set day of dayStart to d
set month of dayStart to m
set year of dayStart to y
set time of dayStart to 0

set alarmTime to dayStart + 9 * 3600 -- 当天上午 9:00 提醒

set theDesc to "第一行" & return & "第二行" -- 多行用 & return & 拼接

tell application "Calendar"
    tell calendar "个人"
        set ev to make new event with properties {summary:"标题", start date:dayStart, end date:(dayStart + 1 * days), allday event:true, description:theDesc}
        tell ev
            make new display alarm with properties {trigger date:alarmTime}
        end tell
    end tell
end tell
APPLESCRIPT
```

## 日历选择
先探测日历名，选**本地可写**日历（如「个人」「工作」「日历」），避开只读订阅日历（节假日 / 生日 / Siri 建议）：
```applescript
tell application "Calendar"
    set AppleScript's text item delimiters to " | "
    return (name of calendars) as string
end tell
```

## 与 Reminders 切换（避免重复）
用户从 reminder 改用 calendar 时，先删 Reminders 同名条目：
```applescript
tell application "Reminders"
    delete (every reminder whose name is "标题")
end tell
```

## 陷阱
- **日期组件顺序**：先 `day` 后 `month` 再 `year`（防跨月溢出，同 reminder 陷阱）
- **全天事件**：`allday event:true` 需配 `end date = start + 1 day`
- **description 多行**：用 `& return &`，`\n` 不是换行（同 reminder 陷阱）
- **display alarm**：用 `trigger date` 指定具体提醒时刻；全天事件 start 是 0:00，不设 alarm 会在凌晨通知

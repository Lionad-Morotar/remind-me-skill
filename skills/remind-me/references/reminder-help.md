# Reminders 提醒事项（macOS）

## 适用场景
**任务型提醒**：需要勾选完成、会留在列表里的事项（待办、任务清单）。

一次性、到点即过的提醒（如"X 天后复盘"）**建议改用 [calendar-help.md](calendar-help.md)**——事件过了自动成为历史，不会像 reminder 那样赖在列表里需手动清理。

## 基础创建
```bash
osascript -e '
  tell application "Reminders"
    make new reminder with properties {name:"标题", body:"单行内容"}
  end tell
'
```

## 带触发时间的提醒（due date）
给 reminder 设 `due date`，系统到点在通知中心/锁屏原生提醒，**无需后台 sleep 进程**。适合"X 天/月后提醒我回来复盘"这类不需强制打断、到点知晓即可的场景。

```bash
osascript <<'APPLESCRIPT'
-- 用 date -v 动态算目标日期，避免月底跨月溢出
set y to (do shell script "date -v+3m +%Y") as integer
set m to (do shell script "date -v+3m +%m") as integer
set d to (do shell script "date -v+3m +%d") as integer

set theDate to current date
set day of theDate to d
set month of theDate to m
set year of theDate to y
set time of theDate to 32400 -- 上午 9:00

set theBody to "第一行" & return & "第二行" -- 多行内容用 return 拼接，见下方陷阱

tell application "Reminders"
    make new reminder with properties {name:"复盘：xxx", body:theBody, due date:theDate}
end tell
APPLESCRIPT
```

## AppleScript 陷阱（实测）
- **不要设 `remind` 属性**：新版 Reminders.app 的 AppleScript 不接受 `set remind of <reminder> to true`，报 `-1700 不能转换为 specifier 类型`。设了 `due date` 系统即会在到点触发原生提醒，无需额外标志。
- **日期组件顺序**：先 `day` 再 `month` 再 `year`。若当前日（如 31 号）超过目标月天数，直接 `set month` 会让月份溢出到下一个月。
- **多行 body 用 `& return &` 拼接**：不要在 `properties {…}` 字典里直接写跨多行字面字符串，易与字典括号配对混淆触发语法错误。先 `set theBody to "a" & return & "b"`，再 `body:theBody`。
- **`\n` 不是换行**：AppleScript 字符串里的 `\n` 是字面两字符，不会被解释成换行，只能用 `& return &`。
- **不指定 list 更稳**：`tell list "提醒事项"` 在非中文 locale 或列表被重命名时失配；直接 `make new reminder` 进默认列表，跨 locale 更可靠。

## 清理同名旧条目（幂等）
重新创建前或切换到 calendar 时，先删旧条目：
```applescript
tell application "Reminders"
    delete (every reminder whose name is "标题")
end tell
```

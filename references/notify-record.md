## 工作流程

Mac 平台执行示例：

```bash
osascript -e '
  tell application "Reminders"
    tell list "提醒事项"
      make new reminder with properties {name:"📖 DeskTerm 学习 Day1: Swift 基础 — 官方 Guided Tour (2h)",
        body:"https://docs.swift.org/swift-book/GuidedTour.html\n重点: enum/struct/class、optional、闭包语法"}
    end tell
  end tell
'
```

Windows 平台执行示例：

```powershell
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show("📖 DeskTerm 学习 Day1: Swift 基础 — 官方 Guided Tour (2h)`nhttps://docs.swift.org/swift-book/GuidedTour.html`n重点: enum/struct/class、optional、闭包语法", "提醒事项")
```

## 带触发时间的提醒（due date）

记录型同样支持“到指定时间触发原生通知”：给 reminder 设 `due date`，系统到点会在通知中心/锁屏提醒，无需后台 sleep 进程。适合“X 天/月后提醒我回来复盘”这类不需要强制打断、到点知晓即可的场景。

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
    -- 不指定 list，进入默认列表，跨 locale 更稳（见下方陷阱）
    make new reminder with properties {name:"复盘：xxx", body:theBody, due date:theDate}
end tell
APPLESCRIPT
```

## AppleScript 陷阱

下方均为实测踩到的坑，记录在此避免重复：

- **不要设 `remind` 属性**：新版 Reminders.app 的 AppleScript 不接受 `set remind of <reminder> to true`，会报 `-1700 不能转换为 specifier 类型`。设了 `due date` 系统即会在到点触发原生提醒，无需额外标志。
- **设日期组件的顺序**：先 `day` 再 `month` 再 `year`。若当前日（如 31 号）超过目标月天数，直接 `set month` 会让月份溢出到下一个月。
- **多行 body 用 `& return &` 拼接**：不要在 `properties {…}` 的字典里直接写跨多行的字面字符串，易与字典的括号配对混淆触发语法错误。先 `set theBody to "a" & return & "b"`，再把变量传给 `body:theBody`。
- **`\n` 不是换行**：AppleScript 字符串里的 `\n` 是字面两字符，不会被解释成换行，只能用 `& return &`。上方旧示例中的 `body:"…\n…"` 实际不会渲染换行。
- **不指定 list 更稳**：`tell list "提醒事项"` 在非中文 locale 或列表被重命名时会失配；直接 `make new reminder` 进入默认列表，跨 locale 更可靠。
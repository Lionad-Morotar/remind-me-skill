# Stickies 桌面便签（macOS）

## 适用场景
桌面常驻展示型内容（能力演示、长期备忘贴在桌面）。**不是定时提醒**，贴上即长期存在，直到用户手动关闭。

## 能力边界（重要）
Stickies.app **没有 AppleScript 对象模型**：
- `make new stickie` 报"变量 stickie 未定义"
- `sdef /System/Applications/Stickies.app` 报 -192（脚本字典编译在二进制，sdef 提取不出）
- 无法用脚本读/写便签的文本内容、颜色、富文本属性

可行通道（三条组合）：
1. **GUI 快捷键**（System Events）：Cmd+N 新建、Cmd+V 粘贴、菜单点颜色
2. **RTF/RTFD 剪贴板**：把富文本与图片灌进便签
3. **System Events 窗口控制**：每个便签是一个 window，可读写 `position` / `size`

## 颜色
顶级「颜色」菜单，6 项：**黄色 / 蓝色 / 绿色 / 粉红色 / 紫色 / 灰色**
```applescript
tell application "System Events"
    tell process "Stickies"
        click menu item "蓝色" of menu "颜色" of menu bar item "颜色" of menu bar 1
    end tell
end tell
```
新便签默认黄色。System Events 读不到颜色，需用户视觉确认。

## 富文本构造
- **纯文本格式**（粗体/斜体/字号/颜色/列表符号）：手写 RTF 即可，AppKit/textutil 都能解析
- **图片**：必须用 AppKit 生成 RTFD，手写 `\pict\pngblip` 不会被 AppKit 识别

图片用 [scripts/stickies_make_rtf.swift](../scripts/stickies_make_rtf.swift)：改顶部 `blocks` 与 `imgPath`，运行 `swift scripts/stickies_make_rtf.swift`，自动把 RTFD + flat RTF 双类型写剪贴板。

## 关键陷阱（实测，务必遵守）
1. **JXA 不暴露 NSAttributedString 的 `initWithString:` 重载**：驼峰 `initWithString` 和方括号 `['initWithString:attributes:']` 都返回 undefined（JXA ObjC bridge 对重载 selector 系统性盲区）。富文本构造一律用 **Swift**，不用 JXA。
2. **`doc.rtf(from:)` 丢弃图片附件**：AppKit 的扁平 RTF 导出设计上不序列化 NSTextAttachment；手写 `\pict` 同样不被识别。必须用 `doc.rtfd(from:)` 拿到含图片的序列化 Data。
3. **`textutil -convert rtf`（RTFD→RTF）也丢图片**，别用来扁平化。
4. **NSTextAttachment 必须有 fileWrapper**：只设 `att.image = img` 不够。用 `FileWrapper(regularFileWithContents: data)` + `preferredFilename = "x.png"`，再 `NSTextAttachment(fileWrapper: wrapper)`。`FileWrapper(url:options:[])` 是惰性读取，导出读不到内容，**别用**。
5. **剪贴板同时写 `.rtfd` + `.rtf`**：只写 `public.rtf` 会丢图。Stickies 粘贴时读 RTFD 类型图片才保留。

## 便签规格
- **目标尺寸 320×300**（无已有时用此默认）
- **已有便签时跟随**：新便签尺寸 = 已有便签尺寸；位置 = (已有 x, 已有底部 y + 20)
- **不重叠 / 上下排列 / 间隔 20px**

定位用 System Events（window 1 = 最新最前便签）：
```applescript
tell application "System Events"
    tell process "Stickies"
        set size of window 1 to {320, 300}
        set position of window 1 to {258, 340}
    end tell
end tell
```

## 完整流程
1. **探测现有便签**：System Events 读 `process "Stickies"` 的 windows（position/size/数量）
2. **生成富文本**：改 `scripts/stickies_make_rtf.swift` 的 `blocks` + `imgPath`，`swift scripts/stickies_make_rtf.swift`（自动写剪贴板双类型）
3. **GUI 新建**：Cmd+N（默认黄）
4. **设色**：GUI 点「颜色」菜单
5. **粘贴**：Cmd+V
6. **定位定尺寸**：System Events 设 window 1 的 size/position（跟随已有或 320×300）

## 贴后验证
复查窗口数与各 window position/size，确认不重叠、尺寸一致：
```applescript
tell application "System Events"
    tell process "Stickies"
        set cnt to count of windows
        set out to ""
        repeat with i from 1 to cnt
            set p to position of window i
            set s to size of window i
            set out to out & "win" & i & " pos=" & ((item 1 of p) as string) & "," & ((item 2 of p) as string) & " size=" & ((item 1 of s) as string) & "," & ((item 2 of s) as string) & linefeed
        end repeat
        return "窗口数=" & cnt & linefeed & out
    end tell
end tell
```

## GUI 全流程模板
```applescript
tell application "Stickies" to activate
delay 0.5
tell application "System Events"
    keystroke "n" using command down
    delay 0.6
    tell process "Stickies"
        click menu item "蓝色" of menu "颜色" of menu bar item "颜色" of menu bar 1
    end tell
    delay 0.2
    keystroke "v" using command down
    delay 0.9
    tell process "Stickies"
        set size of window 1 to {320, 300}
        set position of window 1 to {258, 340}  -- 改为：已有便签 x, 已有底部 y+20
    end tell
end tell
```

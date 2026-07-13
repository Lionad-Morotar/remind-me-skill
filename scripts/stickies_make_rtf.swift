#!/usr/bin/env swift
// Stickies 富文本便签生成器
// 构造 NSAttributedString（含图片附件）→ RTFD Data（含图）+ flat RTF（fallback）→ 写入剪贴板双类型
// 用法：修改下方 blocks / imgPath，运行 `swift scripts/stickies_make_rtf.swift`，
//       随后执行 references/stickies-help.md 中的 GUI 模板（Cmd+N 新建 + 颜色 + Cmd+V 粘贴 + 定位）
import AppKit

// ---- 颜色调色板（按需增减）----
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    return NSColor(calibratedRed: r/255, green: g/255, blue: b/255, alpha: 1)
}
let C_TITLE = rgb(30,40,90), C_SUB = rgb(95,95,105),
    C_RED = rgb(200,40,40), C_BLUE = rgb(40,70,200),
    C_GREEN = rgb(40,150,70), C_BLACK = rgb(30,30,30)

// ---- 内容区：改这里 ----
// 每段 = (文本, 字号, 粗体, 斜体, 颜色)；特殊段 "IMG" 插入图片
let imgPath = "/tmp/sticky_img.png"
let blocks: [(String, CGFloat, Bool, Bool, NSColor)] = [
    ("便笺能力全要素展示\n", 28, true, false, C_TITLE),
    ("Stickies 富文本 / 图形 演示条\n\n", 14, false, true, C_SUB),
    ("一、列表与粗斜体\n", 16, true, false, C_BLACK),
    ("•　第一项：普通正文条目\n", 14, false, false, C_BLACK),
    ("•　第二项：", 14, false, false, C_BLACK),
    ("粗体强调", 14, true, false, C_RED),
    (" 与 ", 14, false, false, C_BLACK),
    ("斜体补充\n", 14, false, true, C_BLUE),
    ("•　第三项：", 14, false, false, C_BLACK),
    ("粗斜体混排\n\n", 14, true, true, C_GREEN),
    ("二、字号阶梯\n", 16, true, false, C_BLACK),
    ("12pt 正文 / ", 12, false, false, C_BLACK),
    ("16pt 中号 / ", 16, false, false, C_BLACK),
    ("22pt 大号\n\n", 22, false, false, C_BLACK),
    ("三、彩色文字\n", 16, true, false, C_BLACK),
    ("红色 ", 14, true, false, C_RED),
    ("蓝色 ", 14, true, false, C_BLUE),
    ("绿色\n\n", 14, true, false, C_GREEN),
    ("四、内嵌图形（PNG 位图）\n", 16, true, false, C_BLACK),
    ("IMG", 0, false, false, C_BLACK),
    ("\n（上方为脚本生成的三色条纹位图）\n", 11, false, true, C_SUB),
]

let doc = NSMutableAttributedString()
func pingfang(_ size: CGFloat, _ bold: Bool, _ italic: Bool) -> NSFont {
    let fm = NSFontManager.shared
    var t: NSFontTraitMask = []
    if bold { t.insert(.boldFontMask) }
    if italic { t.insert(.italicFontMask) }
    return fm.font(withFamily: "PingFang SC", traits: t, weight: 0, size: size) ?? NSFont.systemFont(ofSize: size)
}

for b in blocks {
    if b.0 == "IMG" {
        // 图片附件：必须 fileWrapper（regularFileWithContents 立即持数据 + preferredFilename 识别为 PNG）
        let u = URL(fileURLWithPath: imgPath)
        if let data = try? Data(contentsOf: u) {
            let w = FileWrapper(regularFileWithContents: data)
            w.preferredFilename = u.lastPathComponent
            let att = NSTextAttachment(fileWrapper: w)
            att.image = NSImage(contentsOfFile: imgPath)
            doc.append(NSAttributedString(attachment: att))
        }
    } else {
        doc.append(NSAttributedString(string: b.0, attributes: [
            .font: pingfang(b.1, b.2, b.3),
            .foregroundColor: b.4
        ]))
    }
}

// RTFD（含图片）+ flat RTF（fallback）双类型写剪贴板
let range = NSRange(location: 0, length: doc.length)
guard let rtfdData = try? doc.rtfd(from: range, documentAttributes: [:]),
      let rtfData = try? doc.rtf(from: range, documentAttributes: [:]) else {
    fputs("RTF/RTFD 生成失败\n", stderr); exit(1)
}

let pb = NSPasteboard.general
pb.clearContents()
pb.declareTypes([.rtfd, .rtf], owner: nil)
pb.setData(rtfdData, forType: .rtfd)
pb.setData(rtfData, forType: .rtf)

var hasImg = false
if let rep = try? NSAttributedString(rtfd: rtfdData, documentAttributes: nil) {
    rep.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rep.length), options: []) { v, _, stop in
        if v != nil { hasImg = true; stop.pointee = true }
    }
}
print("RTFD bytes=\(rtfdData.count) | flat RTF bytes=\(rtfData.count) | 含图片附件=\(hasImg)")
print("剪贴板已写入 .rtfd + .rtf 双类型。接下来执行 GUI：Cmd+N 新建 → 颜色菜单 → Cmd+V 粘贴 → System Events 定位")

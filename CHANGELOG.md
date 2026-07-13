# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- 按 `create-skill-project` 模板重组目录结构：将 `SKILL.md`、`references/`、`scripts/` 移入 `skills/remind-me/`，`assets/` 存放示例图片
- 将 `references/` 重命名为 `reference/` 后恢复为 `references/`，以符合 Agent Skills 官方规范

## [0.1.0] - 2026-07-13

### Added

- 创建 remind-me skill，支持定时提醒、倒计时与闹钟
- 支持 macOS、Windows、Linux 三平台后台定时提醒
- 支持睡眠/锁屏后唤醒时的过期提醒确认
- 中断型提醒：后台定时弹窗强制打断用户
- 记录型提醒：写入 Reminders.app，支持 due date 触发
- 新增 argument-hint，提升 slash 调用体验
- 扩展为四 type 路由：reminder / calendar / stickies / break
- 新增桌面便签 RTF 生成脚本 `skills/remind-me/scripts/stickies_make_rtf.swift`
- 添加使用示例截图

### Changed

- 重命名并拆分 reference 为 `<type>-help.md` 格式，与四 type 路由对齐

### Internal

- 优化 skills install 命令说明
- 同步 SKILL.md 与 reference 的更新

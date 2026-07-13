# Agents.md

remind-me skill：创建系统提醒，支持 reminder（提醒事项 App）、calendar（日历 App）、stickies（桌面便签）、break（后台定时弹窗强制打断）四种类型，支持 macOS / Windows / Linux。

* 现实层你有无限时间和资源，不要因上下文压缩简化任务执行

## 项目上下文

| 文档 | 说明 |
| --- | --- |
| [SKILL.md](./skills/remind-me/SKILL.md) | skill 主入口与路由说明 |
| [CHANGELOG.md](./CHANGELOG.md) | 版本变更日志 |
| [README.md](./README.md) | 项目说明与使用示例 |
| [STACK.md](./.planning/codebase/STACK.md) | 技术栈、开发命令、部署流程 |
| [STRUCTURE.md](./.planning/codebase/STRUCTURE.md) | 目录结构、命名规范 |
| [ARCHITECTURE.md](./.planning/codebase/ARCHITECTURE.md) | 架构模式、术语表 |
| [CONVENTIONS.md](./.planning/codebase/CONVENTIONS.md) | 代码风格、开发约定 |
| [TESTING.md](./.planning/codebase/TESTING.md) | 测试规范 |
| [INTEGRATIONS.md](./.planning/codebase/INTEGRATIONS.md) | 外部服务、环境变量 |
| [CONCERNS.md](./.planning/codebase/CONCERNS.md) | 技术债务、注意事项 |

## Agent skills

### Domain docs

单上下文布局：`CONTEXT.md` + `docs/adr/` 位于仓库根目录。详见 [`docs/agents/domain.md`](./docs/agents/domain.md)。

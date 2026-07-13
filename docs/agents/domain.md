# 领域文档

工程技能在探索代码库时应如何消费本项目的领域文档。

## 探索前请先阅读

- 仓库根目录的 **`CONTEXT.md`**，或
- 如果存在，仓库根目录的 **`CONTEXT-MAP.md`** —— 它指向每个上下文的 `CONTEXT.md`，按主题阅读相关文件。
- **`docs/adr/`** —— 阅读与你即将工作领域相关的 ADR。多上下文仓库中，还需检查 `src/<context>/docs/adr/` 下的上下文级决策。

如果这些文件不存在，**静默继续**。不要标记其缺失，也不要主动建议创建。生产技能（`/grill-with-docs`）会在术语或决策真正确定时惰性创建它们。

## 文件结构

单上下文仓库（大多数仓库）：

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

多上下文仓库（根目录存在 `CONTEXT-MAP.md`）：

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← 全系统决策
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← 上下文级决策
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## 使用术语表词汇

当你的输出命名领域概念（issue 标题、重构提案、假设、测试名）时，使用 `CONTEXT.md` 中定义的术语。不要偏离术语表明确避免的同义词。

如果你需要的概念尚未在术语表中，这是一个信号 —— 要么你在发明项目不使用的语言（请重新考虑），要么存在真实缺口（记录下来供 `/grill-with-docs` 处理）。

## 标记 ADR 冲突

如果你的输出与现有 ADR 矛盾，请显式提出，而不是静默覆盖：

> _与 ADR-0007（event-sourced orders）冲突 —— 但值得重新讨论，因为…_

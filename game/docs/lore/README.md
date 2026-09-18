# 南疆肉鸽知识库

本目录是《南疆凡人一局制》游戏设计的设定护栏。它不替代原著，也不替代游戏设计文档；其作用是让每一项可见内容、规则改编和原创内容都能被追溯与审查。

## Lore Compiler V1

`lore_engine/` 是独立的本地 Lore Compiler。V1 将第一卷前 10 个 canonical section 转换为带来源、引文和 checkpoint 的 SQLite 中间数据，作为后续审查和适配的结构化真值。

现有 `canon-index.md`、`adaptation-register.md` 和 `game-rule-register.md` 在迁移期仍是人工可读的审查视图；编译器通过 `lore_sources/seeds/` 追加导入，不会覆盖这些文档。`generated/lore/` 下的数据库、缓存、checkpoint 和报告均可重建，不属于 Godot 运行时内容。

V1 不会写入 `data/*.json`，也不会修改 `ContentCatalog`、Godot 场景、领域脚本或原文。只有未来经过人工批准的适配记录，才可以进入 Godot 数据体系。

本地入口：

```powershell
tools/lore.ps1 ingest --manifest lore_sources/manifest.json --verify-only
tools/lore.ps1 index --source-file-id gu_zhenren_main --section-limit 10
tools/lore.ps1 run --backend fixture --resume
tools/lore.ps1 validate --database generated/lore/lore-v1.sqlite
tools/lore.ps1 report --database generated/lore/lore-v1.sqlite
```

## 使用规则

1. 新增蛊虫、传承、势力、事件、首领或遗藏前，先在 `canon-index.md` 检索是否有原著依据。
2. 原著确有依据的内容，引用对应 `CAN-` 条目；不把推论、平衡数值或视觉想象描述成原著事实。
3. 为可玩性扩展、合并、简化或转换原著概念时，在 `adaptation-register.md` 新增或引用 `ADP-` 条目。
4. 完全原创的游戏内容必须标为 `original_game_content`，不得伪称原著设定。
5. 内容数据表遵守 `content-source-schema.md`；源代码标识符和 JSON 键保持 ASCII，玩家可见文本使用中文。

## 证据等级

`A` 原文直接陈述；`B` 原文可稳定推导；`C` 为游戏化改编；`O` 为原创游戏内容。

事实判断遵循仓库记忆库的规则：

`蛊真人-clean.txt` 与《人祖传》原文 > 读书笔记 > 其他派生文档。

`肉鸽设计-原始数据/` 是专题整理材料，可帮助检索与标记后期机制边界，但不高于原文。`旧稿归档_不采用/` 不可作为事实或设计依据。

## 当前边界

本知识库服务于南疆凡人 60--90 分钟的一局制肉鸽。它不会把蛊仙阶段的仙窍、道痕、仙元石、灾劫等机制下放成凡人阶段的常规成长系统。升仙仅作为本局的最终考验，其规则必须通过改编条目明确标示。

## 文档

- `canon-index.md`：可直接引用的原著事实与误读边界。
- `adaptation-register.md`：每个游戏化转换的依据、偏离点与禁止越界项。
- `game-rule-register.md`：用户已确认的游戏规则；它与原著事实索引分开维护。
- `content-source-schema.md`：未来内容数据应保留的来源字段与审查流程。

---
title: Meta 图鉴
description: 跨局保留的图鉴型 Meta Progression、事件日志归因机制与零数值成长原则
date: 2026-09-12
tags: [meta-progression, codex, save, persistence]
---

蛊方图鉴是唯一明确允许的跨局内容解锁；不得新增其他跨局战力成长——这是核心业务红线[^1]。死亡后 Run 侧清空蛊/材料/遗物等临时集合，事件日志保留供归因；Meta 侧永久保留[^2]。

## MetaProgress 11 字段

`gu_codex_ids`（蛊图鉴）、`recipe_codex_ids`（蛊方图鉴）、`relic_codex_ids`、`inheritance_codex_ids`、`unlocked_content_ids`、`unlocked_random_outcomes`、`contracts_unlocked`、`journal_unlocked`、`hall_material_bonus_accrued`（仅展示）、`dda_state_adaptive_enabled`（每局拷入）、`statistics`（runs_started/won/risky/deaths）[^2]。

## 归因机制：事件日志回放

Meta 解锁只能从不可变事件日志推导：`refinement_succeeded` / `scavenge_recipe_unlocked` → 蛊方图鉴；`relic_gained` → 遗物图鉴（带目录校验）；结局匹配 → 契约解锁；route 标记白名单（boss_defeated、sworn_contracts、ascension_attempted、shop_barter、notoriety_gte_5、rest_curse_removed）→ 手记[^2]。全程 `_copy()` 不可变更新[^2]。

## 新局注入

`RunState.new_run` 把 `global_codex_ids = meta.recipe_codex_ids + gu_codex_ids` 注入，图鉴决定新局配方门禁[^2]。事件日志同时服务存档校验（`event_%04d` 连续性）、Meta 归因、结局归因、调试——单一机制四用，是最高重构成本点之一[^2]。

## 存档技术

双 JSON（大厅档/Run 档）+ SAVE_VERSION 4（v3 大厅档迁移保留、v3 Run 档拒绝）+ 原子写（tmp→rename）+ 递归 XOR 校验和[^2]。规则升级可拒绝不兼容的进行中 Run，但必须迁移保留大厅进度与图鉴[^3]。实现细节见 [RunState 与存档](../entities/run-state-and-saves.md)。

## 设计取向

纯知识/图鉴型 Meta，零永久数值——不破坏"每一局重新建立资源体系"的核心乐趣，但跨局成长感较薄：Meta 只影响"能配什么"，不影响"世界如何反应"。这是取向而非缺陷，审计建议外部审阅者排优先级[^2]。

## 关联页面

- 状态与存档实现 → [RunState 与存档](../entities/run-state-and-saves.md)
- 结局归并规则 → [核心玩法循环](gameplay-loop.md)

[^1]: AGENTS.md, 核心业务红线
[^2]: PROJECT_WORLD_MODEL_AUDIT.md, §19/§21（route 白名单枚举现源：scripts/domain/content_catalog.gd 与 scripts/domain/meta_progress.gd）
[^3]: docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md, §0.1

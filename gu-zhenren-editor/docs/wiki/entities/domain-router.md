---
title: 领域路由核
description: resolver.gd 拆分现状、四命令族模块与 55 种命令分发表的结构
date: 2026-09-12
tags: [resolver, architecture, domain, routing]
---

resolver.gd 已从 2407 行的 P1 god-file 拆为 273 行纯路由核（`apply` → `_handler_for` → 静态 `_dispatch` 表）+ 四命令族模块单向 preload + 薄转发；跨模块引用一律 `Resolver._xxx`[^1]。

## 命令族模块

| 模块 | 行数 | 职责 |
|---|---|---|
| social_command_rules.gd | 955 | travel/contact/ascension/curse/boss 等 |
| refine_command_rules.gd | 828 | 炼蛊/卡片/搜刮/材料 |
| shop_command_rules.gd | 448 | 黑市货架/购买/以物易物 |
| run_command_rules.gd | 271 | T9.2 v2 命令族 14 种（confirm_core/feed_instance/dodge/grapple 等） |

另有 rest_rules.gd 237 行、resolver_helpers.gd 26 行；`_dispatch` 表约 55 种命令 type（懒加载 static var）[^1]。

**文档-代码漂移警告**：契约文本写"205 行路由核"、纠偏计划写 261 行，实测 273 行——引用行数时以代码为准[^1]。

## 命令流

UI → `run_controller.submit_command`（905 行，四路分发：save/load → RunSaveFlow；travel/dialogue → RunTravelFlow/RunDialogueFlow；战斗硬编码类型表 → RunBattleFlow；节点会话 → EncounterSessionResolver，兜底 → Resolver.apply）[^1]。命令入口唯一是红线：禁止散落全局 Run 状态或绕过统一命令入口[^2]。

## 设计约束

- 领域层不依赖表现层；依赖方向只允许 表现层→领域层→数据层[^3]。
- 修改 resolver.gd 走 Shared 单写者区 5 步协议 → [Agent 协作](../concepts/agent-ownership.md)。
- 模块接口页：docs/contracts/module-interfaces/07-domain-action-router.md 是本实体的权威接口契约[^3]。

## 关联页面

- 战斗命令族 → [v1 战斗引擎](v1-battle-resolver.md)
- 状态边界 → [RunState 与存档](run-state-and-saves.md)

[^1]: PROJECT_WORLD_MODEL_AUDIT.md, §21
[^2]: AGENTS.md, 禁止项
[^3]: docs/contracts/module-interfaces/README.md
